-- Drop all existing policies
DO $$ 
BEGIN
  -- Drop gift_projects policies
  DROP POLICY IF EXISTS "View accessible projects" ON gift_projects;
  DROP POLICY IF EXISTS "View projects by invite code" ON gift_projects;
  DROP POLICY IF EXISTS "Select projects" ON gift_projects;
  DROP POLICY IF EXISTS "Anyone can view projects with invite code" ON gift_projects;
  
  -- Drop project_members policies
  DROP POLICY IF EXISTS "View project members" ON project_members;
  DROP POLICY IF EXISTS "Insert project members" ON project_members;
  DROP POLICY IF EXISTS "Update project members" ON project_members;
  DROP POLICY IF EXISTS "Delete project members" ON project_members;
  DROP POLICY IF EXISTS "Members can view" ON project_members;
  DROP POLICY IF EXISTS "Members can insert" ON project_members;
  DROP POLICY IF EXISTS "Members can update" ON project_members;
  DROP POLICY IF EXISTS "Members can delete" ON project_members;
END $$;

-- Create comprehensive project visibility policy
CREATE POLICY "View accessible projects"
  ON gift_projects FOR SELECT
  TO authenticated
  USING (
    created_by = auth.uid() -- User is the creator
    OR 
    EXISTS ( -- User is a member (active OR pending)
      SELECT 1 
      FROM project_members 
      WHERE project_members.project_id = id 
      AND (
        project_members.user_id = auth.uid()
        OR project_members.email = auth.email()
      )
    )
  );

-- Create policy for anonymous users to view projects by invite code
CREATE POLICY "View projects by invite code"
  ON gift_projects FOR SELECT
  TO anon
  USING (true);  -- We validate the invite code in the application query

-- Create policies for project members
CREATE POLICY "View project members"
  ON project_members FOR SELECT
  TO authenticated
  USING (true);  -- Allow viewing all project members for authenticated users

-- Simplified insert policy that focuses on email-based joins
CREATE POLICY "Insert project members"
  ON project_members FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Allow any authenticated user to insert a member with their own email
    (
      email = auth.email()
      AND status = 'pending'
    )
    OR
    -- Or if they're the project creator
    EXISTS (
      SELECT 1 
      FROM gift_projects 
      WHERE id = project_id 
      AND created_by = auth.uid()
    )
  );

CREATE POLICY "Update project members"
  ON project_members FOR UPDATE
  TO authenticated
  USING (
    -- Project creators can update members
    EXISTS (
      SELECT 1 
      FROM gift_projects 
      WHERE id = project_id 
      AND created_by = auth.uid()
    )
    OR
    -- Users can update their own membership
    (
      email = auth.email()
      OR user_id = auth.uid()
    )
  )
  WITH CHECK (
    -- Project creators can update members
    EXISTS (
      SELECT 1 
      FROM gift_projects 
      WHERE id = project_id 
      AND created_by = auth.uid()
    )
    OR
    -- Users can update their own membership
    (
      email = auth.email()
      OR user_id = auth.uid()
    )
  );

CREATE POLICY "Delete project members"
  ON project_members FOR DELETE
  TO authenticated
  USING (
    -- Project creators can delete members
    EXISTS (
      SELECT 1 
      FROM gift_projects 
      WHERE id = project_id 
      AND created_by = auth.uid()
    )
    OR
    -- Users can delete their own membership
    (
      email = auth.email()
      OR user_id = auth.uid()
    )
  );

-- Grant necessary permissions
GRANT SELECT ON gift_projects TO anon, authenticated;
GRANT ALL ON project_members TO authenticated;