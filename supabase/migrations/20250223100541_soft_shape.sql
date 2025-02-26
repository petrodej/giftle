-- Drop existing policies
DROP POLICY IF EXISTS "View project members" ON project_members;
DROP POLICY IF EXISTS "Insert members" ON project_members;
DROP POLICY IF EXISTS "Update members" ON project_members;
DROP POLICY IF EXISTS "Delete members" ON project_members;

-- Create comprehensive policies for project members
CREATE POLICY "View project members"
  ON project_members FOR SELECT
  TO authenticated
  USING (
    -- Can view if you're a member of the project
    EXISTS (
      SELECT 1 
      FROM project_members pm
      WHERE pm.project_id = project_members.project_id
      AND (
        pm.user_id = auth.uid()
        OR pm.email = auth.email()
      )
    )
    OR
    -- Or if you're the project creator
    EXISTS (
      SELECT 1 
      FROM gift_projects gp
      WHERE gp.id = project_members.project_id
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

CREATE POLICY "Delete members"
  ON project_members FOR DELETE
  TO authenticated
  USING (
    -- Can delete if:
    (
      -- Deleting their own membership
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
  );

-- Ensure proper permissions
GRANT ALL ON project_members TO authenticated;