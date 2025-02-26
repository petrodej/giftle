-- First, ensure we can handle policy drops safely
DO $$ 
BEGIN
  -- Drop existing policies if they exist
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'gift_projects' 
    AND policyname = 'View projects'
  ) THEN
    DROP POLICY "View projects" ON gift_projects;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'gift_projects' 
    AND policyname = 'Access via invite'
  ) THEN
    DROP POLICY "Access via invite" ON gift_projects;
  END IF;

  -- Drop project members policies
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'project_members' 
    AND policyname = 'Insert members'
  ) THEN
    DROP POLICY "Insert members" ON project_members;
  END IF;
END $$;

-- Create policy for authenticated users to view projects
CREATE POLICY "View projects"
  ON gift_projects FOR SELECT
  TO authenticated
  USING (
    created_by = auth.uid()
    OR 
    EXISTS (
      SELECT 1 
      FROM project_members pm
      WHERE pm.project_id = id
      AND (
        -- Match by user_id for confirmed members
        (pm.user_id = auth.uid() AND pm.status = 'active')
        OR 
        -- Match by email for pending members
        (pm.email = auth.email())
      )
    )
  );

-- Create separate policy for anonymous access
CREATE POLICY "Access via invite"
  ON gift_projects FOR SELECT
  TO anon, authenticated
  USING (true);

-- Create policy for joining projects
CREATE POLICY "Insert members"
  ON project_members FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Allow joining if:
    (
      -- The email matches the authenticated user's email
      email = auth.email()
      -- And status is pending
      AND status = 'pending'
      -- And the project exists
      AND EXISTS (
        SELECT 1 
        FROM gift_projects 
        WHERE id = project_id
      )
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

-- Create policy for updating project members
CREATE POLICY "Update members"
  ON project_members FOR UPDATE
  TO authenticated
  USING (
    -- Can update if:
    (
      -- Updating their own membership
      email = auth.email()
      OR user_id = auth.uid()
    )
    OR
    -- Or if they're the project creator
    EXISTS (
      SELECT 1 
      FROM gift_projects 
      WHERE id = project_id 
      AND created_by = auth.uid()
    )
  )
  WITH CHECK (
    -- Same conditions for the new row
    (
      email = auth.email()
      OR user_id = auth.uid()
    )
    OR
    EXISTS (
      SELECT 1 
      FROM gift_projects 
      WHERE id = project_id 
      AND created_by = auth.uid()
    )
  );

-- Ensure proper permissions
REVOKE ALL ON gift_projects FROM anon, authenticated;
GRANT SELECT ON gift_projects TO anon, authenticated;
GRANT ALL ON project_members TO authenticated;