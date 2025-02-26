-- Drop all existing policies
DO $$ 
BEGIN
  -- Drop gift_projects policies
  DROP POLICY IF EXISTS "View projects" ON gift_projects;
  DROP POLICY IF EXISTS "View public projects" ON gift_projects;
  DROP POLICY IF EXISTS "Manage projects" ON gift_projects;
  
  -- Drop project_members policies
  DROP POLICY IF EXISTS "View members" ON project_members;
  DROP POLICY IF EXISTS "Manage members" ON project_members;
END $$;

-- Create simplified policies for gift_projects
CREATE POLICY "View projects"
  ON gift_projects FOR SELECT
  TO authenticated
  USING (
    -- User is the creator
    created_by = auth.uid()
    OR 
    -- User is a member (by user_id or email)
    id IN (
      SELECT project_id 
      FROM project_members 
      WHERE (user_id = auth.uid() OR email = auth.email())
      AND status = 'active'
    )
  );

CREATE POLICY "View public projects"
  ON gift_projects FOR SELECT
  TO anon, authenticated
  USING (true);  -- We'll validate the invite code in the application

CREATE POLICY "Manage projects"
  ON gift_projects FOR ALL
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

-- Create simplified policies for project_members
CREATE POLICY "View members"
  ON project_members FOR SELECT
  TO authenticated
  USING (
    -- Can view if:
    -- You're a member of the project
    project_id IN (
      SELECT project_id 
      FROM project_members 
      WHERE user_id = auth.uid() OR email = auth.email()
    )
    OR
    -- Or if you're the project creator
    project_id IN (
      SELECT id FROM gift_projects WHERE created_by = auth.uid()
    )
  );

CREATE POLICY "Manage members"
  ON project_members FOR ALL
  TO authenticated
  USING (
    -- Can manage if:
    -- You're the project creator
    project_id IN (
      SELECT id FROM gift_projects WHERE created_by = auth.uid()
    )
    OR
    -- Or you're managing your own membership
    (user_id = auth.uid() OR email = auth.email())
  )
  WITH CHECK (
    -- Can only create/update if:
    -- You're the project creator
    project_id IN (
      SELECT id FROM gift_projects WHERE created_by = auth.uid()
    )
    OR
    -- Or you're managing your own membership
    email = auth.email()
  );

-- Ensure proper permissions
GRANT SELECT ON gift_projects TO anon, authenticated;
GRANT ALL ON project_members TO authenticated;