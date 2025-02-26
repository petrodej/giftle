-- Drop existing policies
DROP POLICY IF EXISTS "View projects by invite code" ON gift_projects;
DROP POLICY IF EXISTS "View accessible projects" ON gift_projects;
DROP POLICY IF EXISTS "Join project" ON project_members;
DROP POLICY IF EXISTS "Insert project members" ON project_members;

-- Create new policy for authenticated users
CREATE POLICY "View accessible projects"
  ON gift_projects FOR SELECT
  TO authenticated
  USING (
    created_by = auth.uid() -- User is the creator
    OR 
    EXISTS ( -- User is a member (active OR pending)
      SELECT 1 
      FROM project_members 
      WHERE project_members.project_id = id 
      AND (
        project_members.user_id = auth.uid()
        OR project_members.email = auth.email()
      )
    )
  );

-- Create new policy for invite code access
CREATE POLICY "View projects by invite code"
  ON gift_projects FOR SELECT
  TO anon, authenticated
  USING (true);  -- Allow all reads, we'll filter by invite code in the query

-- Create new policy for joining projects
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

-- Ensure proper permissions are granted
GRANT SELECT ON gift_projects TO anon, authenticated;
GRANT INSERT ON project_members TO authenticated;