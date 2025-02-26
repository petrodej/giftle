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
END $$;

-- Create policy for authenticated users
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
        pm.user_id = auth.uid()
        OR pm.email = auth.email()
      )
    )
  );

-- Create separate policy for anonymous access
CREATE POLICY "Access via invite"
  ON gift_projects FOR SELECT
  TO anon
  USING (true);

-- Ensure proper permissions
REVOKE ALL ON gift_projects FROM anon, authenticated;
GRANT SELECT ON gift_projects TO anon, authenticated;