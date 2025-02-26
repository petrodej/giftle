-- Drop all existing policies
DO $$ 
BEGIN
  -- Drop gift_projects policies
  DROP POLICY IF EXISTS "View own projects" ON gift_projects;
  DROP POLICY IF EXISTS "View member projects" ON gift_projects;
  DROP POLICY IF EXISTS "View public projects" ON gift_projects;
  DROP POLICY IF EXISTS "Manage own projects" ON gift_projects;
  
  -- Drop project_members policies
  DROP POLICY IF EXISTS "View own memberships" ON project_members;
  DROP POLICY IF EXISTS "View creator memberships" ON project_members;
  DROP POLICY IF EXISTS "Join projects" ON project_members;
  DROP POLICY IF EXISTS "Creator manage members" ON project_members;
  DROP POLICY IF EXISTS "Manage own membership" ON project_members;
END $$;

-- Create completely separated policies for gift_projects
CREATE POLICY "View own projects"
  ON gift_projects FOR SELECT
  TO authenticated
  USING (created_by = auth.uid());

CREATE POLICY "View member projects"
  ON gift_projects FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM project_members 
      WHERE project_members.project_id = gift_projects.id
      AND project_members.status = 'active'
      AND (
        project_members.user_id = auth.uid()
        OR project_members.email = auth.email()
      )
    )
  );

CREATE POLICY "View public projects"
  ON gift_projects FOR SELECT
  TO anon, authenticated
  USING (true);  -- We'll validate the invite code in the application

CREATE POLICY "Manage own projects"
  ON gift_projects FOR ALL
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

-- Create completely separated policies for project_members
CREATE POLICY "View own memberships"
  ON project_members FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR email = auth.email()
  );

CREATE POLICY "View project memberships"
  ON project_members FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM project_members pm
      WHERE pm.project_id = project_members.project_id
      AND (
        pm.user_id = auth.uid()
        OR pm.email = auth.email()
      )
    )
  );

CREATE POLICY "Join projects"
  ON project_members FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Can only join with own email
    email = auth.email()
  );

CREATE POLICY "Admin manage members"
  ON project_members FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM gift_projects gp
      WHERE gp.id = project_members.project_id
      AND gp.created_by = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 
      FROM gift_projects gp
      WHERE gp.id = project_members.project_id
      AND gp.created_by = auth.uid()
    )
  );

CREATE POLICY "Manage own membership"
  ON project_members FOR UPDATE
  TO authenticated
  USING (
    user_id = auth.uid()
    OR email = auth.email()
  )
  WITH CHECK (
    user_id = auth.uid()
    OR email = auth.email()
  );

-- Ensure proper permissions
GRANT SELECT ON gift_projects TO anon, authenticated;
GRANT ALL ON project_members TO authenticated;