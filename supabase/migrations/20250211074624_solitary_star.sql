-- Drop existing policies
DROP POLICY IF EXISTS "Select projects" ON gift_projects;
DROP POLICY IF EXISTS "Anyone can view projects with invite code" ON gift_projects;

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
      AND project_members.user_id = auth.uid()
    )
    OR
    EXISTS ( -- User has a pending email invitation
      SELECT 1 
      FROM project_members 
      WHERE project_members.project_id = id 
      AND project_members.email = auth.email()
    )
  );

-- Create policy for anonymous users to view projects by invite code
CREATE POLICY "View projects by invite code"
  ON gift_projects FOR SELECT
  TO anon
  USING (true);  -- We validate the invite code in the application query

-- Grant necessary permissions
GRANT SELECT ON gift_projects TO anon, authenticated;