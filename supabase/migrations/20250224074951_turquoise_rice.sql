-- Add created_by column to project_members
ALTER TABLE project_members
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id);

-- Create a temporary table to store unique project_id/email combinations
CREATE TEMP TABLE temp_members AS
SELECT DISTINCT ON (project_id, email)
  project_id,
  email,
  user_id,
  status,
  role,
  joined_at
FROM project_members
ORDER BY project_id, email, joined_at DESC;

-- Delete all existing records from project_members
DELETE FROM project_members;

-- Insert unique records back with created_by from gift_projects
INSERT INTO project_members (
  project_id,
  email,
  user_id,
  status,
  role,
  joined_at,
  created_by
)
SELECT 
  tm.project_id,
  tm.email,
  tm.user_id,
  tm.status,
  tm.role,
  tm.joined_at,
  gp.created_by
FROM temp_members tm
JOIN gift_projects gp ON gp.id = tm.project_id;

-- Drop temporary table
DROP TABLE temp_members;

-- Create trigger to automatically set created_by
CREATE OR REPLACE FUNCTION set_project_member_created_by()
RETURNS TRIGGER AS $$
BEGIN
  -- Get created_by from gift_projects
  SELECT created_by INTO NEW.created_by
  FROM gift_projects
  WHERE id = NEW.project_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_project_member_created_by
  BEFORE INSERT ON project_members
  FOR EACH ROW
  EXECUTE FUNCTION set_project_member_created_by();

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
  DROP POLICY IF EXISTS "View project memberships" ON project_members;
  DROP POLICY IF EXISTS "Join projects" ON project_members;
  DROP POLICY IF EXISTS "Admin manage members" ON project_members;
  DROP POLICY IF EXISTS "Manage own membership" ON project_members;
END $$;

-- Create non-recursive policies for gift_projects
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

-- Create non-recursive policies for project_members
CREATE POLICY "View own memberships"
  ON project_members FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR email = auth.email()
  );

CREATE POLICY "View creator memberships"
  ON project_members FOR SELECT
  TO authenticated
  USING (created_by = auth.uid());

CREATE POLICY "Join projects"
  ON project_members FOR INSERT
  TO authenticated
  WITH CHECK (email = auth.email());

CREATE POLICY "Creator manage members"
  ON project_members FOR ALL
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

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