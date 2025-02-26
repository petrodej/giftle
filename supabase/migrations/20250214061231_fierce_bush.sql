-- Drop existing policies for gift_suggestions
DROP POLICY IF EXISTS "Member access suggestions" ON gift_suggestions;

-- Create separate policies for different operations
CREATE POLICY "View suggestions"
  ON gift_suggestions FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM project_members pm
      WHERE pm.project_id = gift_suggestions.project_id
      AND pm.status = 'active'
      AND (
        pm.user_id = auth.uid()
        OR pm.email = auth.email()
      )
    )
    OR
    EXISTS (
      SELECT 1 
      FROM gift_projects gp
      WHERE gp.id = gift_suggestions.project_id
      AND gp.created_by = auth.uid()
    )
  );

CREATE POLICY "Add suggestions"
  ON gift_suggestions FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Verify active membership
    EXISTS (
      SELECT 1 
      FROM project_members pm
      WHERE pm.project_id = gift_suggestions.project_id
      AND pm.status = 'active'
      AND (
        pm.user_id = auth.uid()
        OR pm.email = auth.email()
      )
    )
    OR
    -- Or verify project creator
    EXISTS (
      SELECT 1 
      FROM gift_projects gp
      WHERE gp.id = gift_suggestions.project_id
      AND gp.created_by = auth.uid()
    )
  );

CREATE POLICY "Manage own suggestions"
  ON gift_suggestions 
  FOR UPDATE
  TO authenticated
  USING (suggested_by = auth.uid())
  WITH CHECK (suggested_by = auth.uid());

CREATE POLICY "Delete suggestions"
  ON gift_suggestions 
  FOR DELETE
  TO authenticated
  USING (
    suggested_by = auth.uid()
    OR
    EXISTS (
      SELECT 1 
      FROM gift_projects gp
      WHERE gp.id = gift_suggestions.project_id
      AND gp.created_by = auth.uid()
    )
  );

-- Ensure proper permissions
GRANT ALL ON gift_suggestions TO authenticated;