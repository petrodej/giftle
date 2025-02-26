-- Drop existing trigger and function
DROP TRIGGER IF EXISTS member_updates ON project_members;
DROP FUNCTION IF EXISTS handle_member_updates();
DROP FUNCTION IF EXISTS join_project(uuid, text);

-- Create or replace the function to handle member updates
CREATE OR REPLACE FUNCTION handle_member_updates()
RETURNS TRIGGER AS $$
DECLARE
  _user_id uuid;
  _email text;
BEGIN
  -- Get current user info
  _user_id := auth.uid();
  _email := auth.email();

  -- When a user joins
  IF TG_OP = 'INSERT' THEN
    -- Always set email to the authenticated user's email if available
    IF _email IS NOT NULL THEN
      NEW.email := _email;
    END IF;

    -- If user is authenticated, set their user_id and make them active
    IF _user_id IS NOT NULL THEN
      NEW.user_id := _user_id;
      NEW.status := 'active';
    ELSE
      -- For email-only invites, set as pending
      NEW.status := COALESCE(NEW.status, 'pending');
    END IF;
  END IF;

  -- When updating an existing member
  IF TG_OP = 'UPDATE' THEN
    -- If user_id is being set and was previously NULL
    IF NEW.user_id IS NOT NULL AND OLD.user_id IS NULL THEN
      -- Activate the membership and ensure email matches
      NEW.status := 'active';
      -- Update email if it was a pending invitation
      IF OLD.status = 'pending' AND _email IS NOT NULL THEN
        NEW.email := _email;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for member updates
CREATE TRIGGER member_updates
  BEFORE INSERT OR UPDATE ON project_members
  FOR EACH ROW
  EXECUTE FUNCTION handle_member_updates();

-- Create function to join project
CREATE OR REPLACE FUNCTION join_project(project_id uuid, invite_code text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _user_id uuid;
  _email text;
BEGIN
  -- Get current user info
  _user_id := auth.uid();
  _email := auth.email();

  -- Verify user is authenticated
  IF _user_id IS NULL OR _email IS NULL THEN
    RAISE EXCEPTION 'User must be authenticated to join project';
  END IF;

  -- Verify invite code
  IF NOT EXISTS (
    SELECT 1 
    FROM gift_projects 
    WHERE id = project_id 
    AND invite_code = join_project.invite_code
  ) THEN
    RAISE EXCEPTION 'Invalid invite code';
  END IF;

  -- Insert or update member
  INSERT INTO project_members (
    project_id,
    email,
    user_id,
    status
  ) 
  VALUES (
    project_id,
    _email,
    _user_id,
    'active'
  )
  ON CONFLICT (project_id, email) 
  DO UPDATE SET
    user_id = EXCLUDED.user_id,
    status = 'active';
END;
$$;

-- Grant necessary permissions
GRANT ALL ON project_members TO authenticated;
GRANT EXECUTE ON FUNCTION join_project TO authenticated;