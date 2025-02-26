-- First, ensure we can handle policy drops safely
DO $$ 
BEGIN
  -- Drop existing policies if they exist
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'gift_projects' 
    AND policyname IN (
      'View projects',
      'Access via invite',
      'Create projects',
      'Update projects',
      'Delete projects'
    )
  ) THEN
    DROP POLICY IF EXISTS "View projects" ON gift_projects;
    DROP POLICY IF EXISTS "Access via invite" ON gift_projects;
    DROP POLICY IF EXISTS "Create projects" ON gift_projects;
    DROP POLICY IF EXISTS "Update projects" ON gift_projects;
    DROP POLICY IF EXISTS "Delete projects" ON gift_projects;
  END IF;
END $$;

-- Create comprehensive project policies
CREATE POLICY "View projects"
  ON gift_projects FOR SELECT
  TO authenticated
  USING (
    -- User is the creator
    created_by = auth.uid()
    OR 
    -- User is a member (active or pending)
    EXISTS (
      SELECT 1 
      FROM project_members pm
      WHERE pm.project_id = id
      AND (
        pm.user_id = auth.uid()
        OR pm.email = auth.email()
      )
    )
  );

-- Create policy for anonymous access via invite code
CREATE POLICY "Access via invite"
  ON gift_projects FOR SELECT
  TO anon, authenticated
  USING (true);  -- We'll validate the invite code in the application

-- Create policy for project creation
CREATE POLICY "Create projects"
  ON gift_projects FOR INSERT
  TO authenticated
  WITH CHECK (
    created_by = auth.uid()
  );

-- Create policy for project updates
CREATE POLICY "Manage projects"
  ON gift_projects FOR ALL
  TO authenticated
  USING (
    created_by = auth.uid()
  )
  WITH CHECK (
    created_by = auth.uid()
  );

-- Ensure proper permissions
REVOKE ALL ON gift_projects FROM anon, authenticated;
GRANT SELECT ON gift_projects TO anon, authenticated;
GRANT ALL ON gift_projects TO authenticated;