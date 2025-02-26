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
    id IN (
      SELECT project_id 
      FROM project_members 
      WHERE (user_id = auth.uid() OR email = auth.email())
    )
  );

-- Create policy for anonymous access
CREATE POLICY "Access via invite"
  ON gift_projects FOR SELECT
  TO anon, authenticated
  USING (true);  -- We'll validate the invite code in the application

-- Create simplified policies for project members
CREATE POLICY "View project members"
  ON project_members FOR SELECT
  TO authenticated
  USING (
    -- Can view if you're a member of the project
    project_id IN (
      SELECT project_id 
      FROM project_members 
      WHERE (user_id = auth.uid() OR email = auth.email())
    )
    OR
    -- Or if you're the project creator
    project_id IN (
      SELECT id 
      FROM gift_projects 
      WHERE created_by = auth.uid()
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
    project_id IN (
      SELECT id 
      FROM gift_projects 
      WHERE created_by = auth.uid()
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
    project_id IN (
      SELECT id 
      FROM gift_projects 
      WHERE created_by = auth.uid()
    )
  )
  WITH CHECK (
    -- Same conditions for new row
    user_id = auth.uid()
    OR email = auth.email()
    OR
    project_id IN (
      SELECT id 
      FROM gift_projects 
      WHERE created_by = auth.uid()
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
    project_id IN (
      SELECT id 
      FROM gift_projects 
      WHERE created_by = auth.uid()
    )
  );

-- Ensure proper permissions
GRANT SELECT ON gift_projects TO anon, authenticated;
GRANT ALL ON project_members TO authenticated;