-- Drop existing policies
DROP POLICY IF EXISTS "View projects" ON gift_projects;
DROP POLICY IF EXISTS "Access via invite" ON gift_projects;
DROP POLICY IF EXISTS "View project members" ON project_members;
DROP POLICY IF EXISTS "Insert members" ON project_members;
DROP POLICY IF EXISTS "Update members" ON project_members;
DROP POLICY IF EXISTS "Delete members" ON project_members;

-- Create base policy for project visibility
CREATE POLICY "View projects"
  ON gift_projects FOR SELECT
  TO authenticated
  USING (
    -- User is the creator
    created_by = auth.uid()
    OR 
    -- User is a member by direct user_id or email match
    EXISTS (
      SELECT 1 
      FROM project_members pm
      WHERE pm.project_id = id
      AND (
        pm.user_id = auth.uid()
        OR pm.email = auth.email()
      )
    )
  );

-- Create policy for anonymous access
CREATE POLICY "Access via invite"
  ON gift_projects FOR SELECT
  TO anon, authenticated
  USING (
    -- Allow access to projects with matching invite code
    invite_code = COALESCE(
      current_setting('request.query.invite_code', true)::text,
      ''
    )
  );

-- Create simplified policies for project members
CREATE POLICY "View project members"
  ON project_members FOR SELECT
  TO authenticated
  USING (
    -- Direct user match
    user_id = auth.uid()
    OR email = auth.email()
    OR
    -- Project creator
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
    -- Self-join with email
    email = auth.email()
    OR
    -- Project creator
    EXISTS (
      SELECT 1 
      FROM gift_projects gp
      WHERE gp.id = project_id 
      AND gp.created_by = auth.uid()
    )
  );

CREATE POLICY "Update members"
  ON project_members FOR UPDATE
  TO authenticated
  USING (
    -- Direct user match
    user_id = auth.uid()
    OR email = auth.email()
    OR
    -- Project creator
    EXISTS (
      SELECT 1 
      FROM gift_projects gp
      WHERE gp.id = project_id 
      AND gp.created_by = auth.uid()
    )
  )
  WITH CHECK (
    -- Same conditions for new row
    user_id = auth.uid()
    OR email = auth.email()
    OR
    EXISTS (
      SELECT 1 
      FROM gift_projects gp
      WHERE gp.id = project_id 
      AND gp.created_by = auth.uid()
    )
  );

CREATE POLICY "Delete members"
  ON project_members FOR DELETE
  TO authenticated
  USING (
    -- Direct user match
    user_id = auth.uid()
    OR email = auth.email()
    OR
    -- Project creator
    EXISTS (
      SELECT 1 
      FROM gift_projects gp
      WHERE gp.id = project_id 
      AND gp.created_by = auth.uid()
    )
  );

-- Ensure proper permissions
GRANT SELECT ON gift_projects TO anon, authenticated;
GRANT ALL ON project_members TO authenticated;