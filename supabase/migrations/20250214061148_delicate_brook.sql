-- Drop existing policies for gift_suggestions
DROP POLICY IF EXISTS "Access suggestions" ON gift_suggestions;
DROP POLICY IF EXISTS "View suggestions" ON gift_suggestions;
DROP POLICY IF EXISTS "Insert suggestions" ON gift_suggestions;
DROP POLICY IF EXISTS "Update suggestions" ON gift_suggestions;
DROP POLICY IF EXISTS "Delete suggestions" ON gift_suggestions;

-- Create simplified policy for gift suggestions
CREATE POLICY "Member access suggestions"
  ON gift_suggestions
  FOR ALL
  TO authenticated
  USING (
    -- Check if user is an active member or project creator
    EXISTS (
      SELECT 1 
      FROM project_members pm
      JOIN gift_projects gp ON gp.id = pm.project_id
      WHERE pm.project_id = gift_suggestions.project_id
      AND (
        -- Is active member
        (pm.status = 'active' AND (
          pm.user_id = auth.uid()
          OR pm.email = auth.email()
        ))
        OR 
        -- Or is project creator
        gp.created_by = auth.uid()
      )
    )
  )
  WITH CHECK (
    -- Same check for write operations
    EXISTS (
      SELECT 1 
      FROM project_members pm
      JOIN gift_projects gp ON gp.id = pm.project_id
      WHERE pm.project_id = gift_suggestions.project_id
      AND (
        -- Is active member
        (pm.status = 'active' AND (
          pm.user_id = auth.uid()
          OR pm.email = auth.email()
        ))
        OR 
        -- Or is project creator
        gp.created_by = auth.uid()
      )
    )
    -- Ensure suggested_by is set to the current user
    AND suggested_by = auth.uid()
  );

-- Ensure proper permissions
GRANT ALL ON gift_suggestions TO authenticated;