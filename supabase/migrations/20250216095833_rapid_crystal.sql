-- Drop existing policies
DROP POLICY IF EXISTS "View projects" ON gift_projects;
DROP POLICY IF EXISTS "Access via invite" ON gift_projects;

-- Create policy for project creation
CREATE POLICY "Create projects"
  ON gift_projects FOR INSERT
  TO authenticated
  WITH CHECK (
    created_by = auth.uid()
  );

-- Create policy for viewing projects
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

-- Create policy for updating projects
CREATE POLICY "Update projects"
  ON gift_projects FOR UPDATE
  TO authenticated
  USING (
    created_by = auth.uid()
  )
  WITH CHECK (
    created_by = auth.uid()
  );

-- Create policy for deleting projects
CREATE POLICY "Delete projects"
  ON gift_projects FOR DELETE
  TO authenticated
  USING (
    created_by = auth.uid()
  );

-- Ensure proper permissions
GRANT ALL ON gift_projects TO authenticated;