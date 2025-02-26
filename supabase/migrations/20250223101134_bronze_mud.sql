-- Drop existing policies
DROP POLICY IF EXISTS "View project members" ON project_members;
DROP POLICY IF EXISTS "Insert members" ON project_members;
DROP POLICY IF EXISTS "Update members" ON project_members;
DROP POLICY IF EXISTS "Delete members" ON project_members;

-- Create simplified policies for project members
CREATE POLICY "View project members"
  ON project_members FOR SELECT
  TO authenticated
  USING (
    -- Can view if you're a member
    user_id = auth.uid()
    OR email = auth.email()
    OR
    -- Or if you're the project creator
    EXISTS (
      SELECT 1 
      FROM gift_projects gp
      WHERE gp.id = project_id 
      AND gp.created_by = auth.uid()
    )
  );

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

CREATE POLICY "Update members"
  ON project_members FOR UPDATE
  TO authenticated
  USING (
    -- Can update if:
    user_id = auth.uid()
    OR email = auth.email()
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
    user_id = auth.uid()
    OR email = auth.email()
    OR
    EXISTS (
      SELECT 1 
      FROM gift_projects 
      WHERE id = project_id 
      AND created_by = auth.uid()
    )
  );

CREATE POLICY "Delete members"
  ON project_members FOR DELETE
  TO authenticated
  USING (
    -- Can delete if:
    user_id = auth.uid()
    OR email = auth.email()
    OR
    -- Or if they're the project creator
    EXISTS (
      SELECT 1 
      FROM gift_projects 
      WHERE id = project_id 
      AND created_by = auth.uid()
    )
  );

-- Ensure proper permissions
GRANT ALL ON project_members TO authenticated;