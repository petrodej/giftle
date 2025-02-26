-- First, ensure we can handle policy drops safely
DO $$ 
BEGIN
  -- Drop existing policies if they exist
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'project_members' 
    AND policyname IN ('Insert members', 'Update members')
  ) THEN
    DROP POLICY IF EXISTS "Insert members" ON project_members;
    DROP POLICY IF EXISTS "Update members" ON project_members;
  END IF;
END $$;

-- Create policy for joining projects
CREATE POLICY "Insert members"
  ON project_members FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Allow joining if:
    (
      -- The email matches the authenticated user's email
      email = auth.email()
      -- And the project exists
      AND EXISTS (
        SELECT 1 
        FROM gift_projects 
        WHERE id = project_id
      )
    )
    OR
    -- Or if they're the project creator
    EXISTS (
      SELECT 1 
      FROM gift_projects 
      WHERE id = project_id 
      AND created_by = auth.uid()
    )
  );

-- Create policy for updating project members
CREATE POLICY "Update members"
  ON project_members FOR UPDATE
  TO authenticated
  USING (
    -- Can update if:
    (
      -- Updating their own membership
      email = auth.email()
      OR user_id = auth.uid()
    )
    OR
    -- Or if they're the project creator
    EXISTS (
      SELECT 1 
      FROM gift_projects 
      WHERE id = project_id 
      AND created_by = auth.uid()
    )
  )
  WITH CHECK (
    -- Same conditions for the new row
    (
      email = auth.email()
      OR user_id = auth.uid()
    )
    OR
    EXISTS (
      SELECT 1 
      FROM gift_projects 
      WHERE id = project_id 
      AND created_by = auth.uid()
    )
  );

-- Create or replace the function to handle member updates
CREATE OR REPLACE FUNCTION handle_member_updates()
RETURNS TRIGGER AS $$
BEGIN
  -- When a user joins, ensure proper status and user_id
  IF TG_OP = 'INSERT' THEN
    -- If user is authenticated, set their user_id and make them active
    IF auth.uid() IS NOT NULL THEN
      NEW.user_id := auth.uid();
      NEW.status := 'active';
    ELSE
      -- Otherwise, set as pending
      NEW.status := 'pending';
    END IF;
  END IF;

  -- When updating an existing member
  IF TG_OP = 'UPDATE' THEN
    -- If user_id is being set and was previously NULL
    IF NEW.user_id IS NOT NULL AND OLD.user_id IS NULL THEN
      -- Activate the membership
      NEW.status := 'active';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create or replace trigger for member updates
DROP TRIGGER IF EXISTS member_updates ON project_members;
CREATE TRIGGER member_updates
  BEFORE INSERT OR UPDATE ON project_members
  FOR EACH ROW
  EXECUTE FUNCTION handle_member_updates();

-- Ensure proper permissions
GRANT ALL ON project_members TO authenticated;