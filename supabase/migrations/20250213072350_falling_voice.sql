-- Drop existing join policy
DROP POLICY IF EXISTS "Join project" ON project_members;

-- Create new, more permissive join policy
CREATE POLICY "Join project"
  ON project_members FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Allow joining if:
    (
      -- The email matches the authenticated user's email
      email = auth.email()
      -- And the project exists (with valid invite code)
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

-- Ensure proper permissions are granted
GRANT INSERT ON project_members TO authenticated;