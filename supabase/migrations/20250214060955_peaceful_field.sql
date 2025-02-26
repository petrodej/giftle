-- Drop existing policies
DROP POLICY IF EXISTS "View projects by invite code" ON gift_projects;
DROP POLICY IF EXISTS "View accessible projects" ON gift_projects;

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

-- Drop existing policies for gift_suggestions
DROP POLICY IF EXISTS "Members can view suggestions" ON gift_suggestions;
DROP POLICY IF EXISTS "Members can add suggestions" ON gift_suggestions;
DROP POLICY IF EXISTS "Members can manage AI suggestions" ON gift_suggestions;

-- Create comprehensive policies for gift suggestions
CREATE POLICY "Access suggestions"
  ON gift_suggestions FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM project_members
      WHERE project_members.project_id = gift_suggestions.project_id
      AND (
        project_members.user_id = auth.uid()
        OR project_members.email = auth.email()
      )
      AND project_members.status = 'active'
    )
    OR
    EXISTS (
      SELECT 1 
      FROM gift_projects
      WHERE gift_projects.id = gift_suggestions.project_id
      AND gift_projects.created_by = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 
      FROM project_members
      WHERE project_members.project_id = gift_suggestions.project_id
      AND (
        project_members.user_id = auth.uid()
        OR project_members.email = auth.email()
      )
      AND project_members.status = 'active'
    )
    OR
    EXISTS (
      SELECT 1 
      FROM gift_projects
      WHERE gift_projects.id = gift_suggestions.project_id
      AND gift_projects.created_by = auth.uid()
    )
  );

-- Ensure proper permissions are granted
GRANT SELECT ON gift_projects TO anon, authenticated;
GRANT ALL ON gift_suggestions TO authenticated;