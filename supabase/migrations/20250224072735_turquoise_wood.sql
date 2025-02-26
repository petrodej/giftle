-- Drop existing policy for viewing project members
DROP POLICY IF EXISTS "View project members" ON project_members;

-- Create improved policy for viewing project members
CREATE POLICY "View project members"
  ON project_members FOR SELECT
  TO authenticated
  USING (
    -- Can view all members if you're a member of the project
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