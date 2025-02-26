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
    -- User is the creator
    created_by = auth.uid()
    OR 
    -- User is a member (active or pending)
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

-- Create policy for invite code access
CREATE POLICY "Access via invite"
  ON gift_projects FOR SELECT
  TO anon, authenticated
  USING (
    -- Allow access to any project
    -- We'll validate the invite code in the application
    true
  );

-- Create or replace function to validate invite codes
CREATE OR REPLACE FUNCTION validate_invite_code(project_id uuid, invite_code text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM gift_projects 
    WHERE id = project_id 
    AND invite_code = validate_invite_code.invite_code
  );
END;
$$;

-- Ensure proper permissions
REVOKE ALL ON gift_projects FROM anon, authenticated;
GRANT SELECT ON gift_projects TO anon, authenticated;
GRANT EXECUTE ON FUNCTION validate_invite_code TO anon, authenticated;