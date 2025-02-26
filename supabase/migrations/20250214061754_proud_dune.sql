-- Drop existing policies for gift_suggestions
DROP POLICY IF EXISTS "View suggestions" ON gift_suggestions;
DROP POLICY IF EXISTS "Add suggestions" ON gift_suggestions;
DROP POLICY IF EXISTS "Manage own suggestions" ON gift_suggestions;
DROP POLICY IF EXISTS "Delete suggestions" ON gift_suggestions;

-- Create comprehensive policies for gift suggestions
CREATE POLICY "View suggestions"
  ON gift_suggestions FOR SELECT
  TO authenticated
  USING (
    -- Can view if you're an active member
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
    -- Or if you're the project creator
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
    -- Can add if you're an active member
    (
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
      -- Ensure suggested_by is set to current user
      AND suggested_by = auth.uid()
    )
    OR
    -- Or if you're the project creator
    EXISTS (
      SELECT 1 
      FROM gift_projects gp
      WHERE gp.id = gift_suggestions.project_id
      AND gp.created_by = auth.uid()
    )
  );

CREATE POLICY "Update own suggestions"
  ON gift_suggestions FOR UPDATE
  TO authenticated
  USING (
    -- Can only update your own suggestions
    suggested_by = auth.uid()
  )
  WITH CHECK (
    -- Ensure suggested_by remains unchanged
    suggested_by = auth.uid()
  );

CREATE POLICY "Delete suggestions"
  ON gift_suggestions FOR DELETE
  TO authenticated
  USING (
    -- Can delete your own suggestions
    suggested_by = auth.uid()
    OR
    -- Or if you're the project creator
    EXISTS (
      SELECT 1 
      FROM gift_projects gp
      WHERE gp.id = gift_suggestions.project_id
      AND gp.created_by = auth.uid()
    )
  );

-- Ensure proper permissions
GRANT ALL ON gift_suggestions TO authenticated;