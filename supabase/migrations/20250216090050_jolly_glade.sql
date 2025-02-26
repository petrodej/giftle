-- Drop existing join_project function
DROP FUNCTION IF EXISTS join_project(uuid, text);

-- Create improved join_project function
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

  -- First try to update any existing membership
  UPDATE project_members
  SET 
    user_id = _user_id,
    status = 'active'
  WHERE 
    project_id = join_project.project_id
    AND (
      email = _email
      OR user_id = _user_id
    );

  -- If no rows were updated, insert a new membership
  IF NOT FOUND THEN
    INSERT INTO project_members (
      project_id,
      email,
      user_id,
      status,
      role
    ) 
    VALUES (
      project_id,
      _email,
      _user_id,
      'active',
      'member'
    );
  END IF;
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION join_project TO authenticated;