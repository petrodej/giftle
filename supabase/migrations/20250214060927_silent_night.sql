-- Drop existing policies for gift_suggestions
DROP POLICY IF EXISTS "Members can view suggestions" ON gift_suggestions;
DROP POLICY IF EXISTS "Members can add suggestions" ON gift_suggestions;
DROP POLICY IF EXISTS "Members can manage AI suggestions" ON gift_suggestions;

-- Create comprehensive policies for gift suggestions
CREATE POLICY "View suggestions"
  ON gift_suggestions FOR SELECT
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
  );

CREATE POLICY "Insert suggestions"
  ON gift_suggestions FOR INSERT
  TO authenticated
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

CREATE POLICY "Update suggestions"
  ON gift_suggestions FOR UPDATE
  TO authenticated
  USING (
    -- Can update if you're the creator of the suggestion
    suggested_by = auth.uid()
    OR
    -- Or if you're the project creator
    EXISTS (
      SELECT 1 
      FROM gift_projects
      WHERE gift_projects.id = gift_suggestions.project_id
      AND gift_projects.created_by = auth.uid()
    )
  )
  WITH CHECK (
    suggested_by = auth.uid()
    OR
    EXISTS (
      SELECT 1 
      FROM gift_projects
      WHERE gift_projects.id = gift_suggestions.project_id
      AND gift_projects.created_by = auth.uid()
    )
  );

CREATE POLICY "Delete suggestions"
  ON gift_suggestions FOR DELETE
  TO authenticated
  USING (
    -- Can delete if you're the creator of the suggestion
    suggested_by = auth.uid()
    OR
    -- Or if you're the project creator
    EXISTS (
      SELECT 1 
      FROM gift_projects
      WHERE gift_projects.id = gift_suggestions.project_id
      AND gift_projects.created_by = auth.uid()
    )
  );

-- Ensure proper permissions are granted
GRANT ALL ON gift_suggestions TO authenticated;