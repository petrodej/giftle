-- Drop existing policies for gift_projects
DROP POLICY IF EXISTS "View accessible projects" ON gift_projects;
DROP POLICY IF EXISTS "View projects by invite code" ON gift_projects;

-- Create comprehensive project visibility policy
CREATE POLICY "View projects"
  ON gift_projects FOR SELECT
  TO authenticated
  USING (
    -- User is the creator
    created_by = auth.uid()
    OR 
    -- User is a member (by user_id or email)
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

-- Create policy for anonymous access via invite code
CREATE POLICY "Access via invite"
  ON gift_projects FOR SELECT
  TO anon, authenticated
  USING (
    -- Only allow access to projects with matching invite code
    invite_code = current_setting('request.headers.invite-code', true)::text
  );

-- Ensure proper permissions
GRANT SELECT ON gift_projects TO anon, authenticated;