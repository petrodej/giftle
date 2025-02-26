-- Drop all existing policies
DO $$ 
BEGIN
  -- Drop gift_projects policies
  DROP POLICY IF EXISTS "View projects" ON gift_projects;
  DROP POLICY IF EXISTS "Access via invite" ON gift_projects;
  DROP POLICY IF EXISTS "Create projects" ON gift_projects;
  DROP POLICY IF EXISTS "Manage projects" ON gift_projects;
  
  -- Drop project_members policies
  DROP POLICY IF EXISTS "View project members" ON project_members;
  DROP POLICY IF EXISTS "Insert members" ON project_members;
  DROP POLICY IF EXISTS "Update members" ON project_members;
  DROP POLICY IF EXISTS "Delete members" ON project_members;
END $$;

-- Create base policies for gift_projects
CREATE POLICY "View own projects"
  ON gift_projects FOR SELECT
  TO authenticated
  USING (created_by = auth.uid());

CREATE POLICY "View member projects"
  ON gift_projects FOR SELECT
  TO authenticated
  USING (
    id IN (
      SELECT project_id 
      FROM project_members 
      WHERE user_id = auth.uid() OR email = auth.email()
    )
  );

CREATE POLICY "View invited projects"
  ON gift_projects FOR SELECT
  TO anon, authenticated
  USING (true);  -- We'll validate the invite code in the application

CREATE POLICY "Manage own projects"
  ON gift_projects FOR ALL
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

-- Create base policies for project_members
CREATE POLICY "View own membership"
  ON project_members FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR email = auth.email());

CREATE POLICY "View project memberships"
  ON project_members FOR SELECT
  TO authenticated
  USING (
    project_id IN (
      SELECT id FROM gift_projects WHERE created_by = auth.uid()
    )
  );

CREATE POLICY "Join project"
  ON project_members FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Can only join with own email
    email = auth.email()
    OR
    -- Or if project creator
    project_id IN (
      SELECT id FROM gift_projects WHERE created_by = auth.uid()
    )
  );

CREATE POLICY "Update own membership"
  ON project_members FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid() OR email = auth.email())
  WITH CHECK (user_id = auth.uid() OR email = auth.email());

CREATE POLICY "Admin update members"
  ON project_members FOR UPDATE
  TO authenticated
  USING (
    project_id IN (
      SELECT id FROM gift_projects WHERE created_by = auth.uid()
    )
  )
  WITH CHECK (
    project_id IN (
      SELECT id FROM gift_projects WHERE created_by = auth.uid()
    )
  );

CREATE POLICY "Delete membership"
  ON project_members FOR DELETE
  TO authenticated
  USING (
    -- Can delete own membership
    user_id = auth.uid() 
    OR email = auth.email()
    OR
    -- Or if project creator
    project_id IN (
      SELECT id FROM gift_projects WHERE created_by = auth.uid()
    )
  );

-- Ensure proper permissions
GRANT SELECT ON gift_projects TO anon, authenticated;
GRANT ALL ON project_members TO authenticated;