-- First, ensure we can handle policy drops safely
DO $$ 
BEGIN
  -- Drop existing policies if they exist
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'gift_projects' 
    AND policyname IN ('View projects', 'Access via invite')
  ) THEN
    DROP POLICY IF EXISTS "View projects" ON gift_projects;
    DROP POLICY IF EXISTS "Access via invite" ON gift_projects;
  END IF;
END $$;

-- Create comprehensive project visibility policy
CREATE POLICY "View projects"
  ON gift_projects FOR SELECT
  TO authenticated
  USING (
    -- User is the admin (creator)
    created_by = auth.uid()
    OR 
    -- User is a member
    EXISTS (
      SELECT 1 
      FROM project_members pm
      WHERE pm.project_id = id
      AND pm.status = 'active'
      AND (
        pm.user_id = auth.uid()
        OR pm.email = auth.email()
      )
    )
  );

-- Create policy for invite code access
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

-- Ensure proper permissions
REVOKE ALL ON gift_projects FROM anon, authenticated;
GRANT SELECT ON gift_projects TO anon, authenticated;