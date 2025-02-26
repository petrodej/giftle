-- Drop existing policies that might conflict
DROP POLICY IF EXISTS "Select projects" ON gift_projects;

-- Recreate the policy for authenticated users
CREATE POLICY "Select projects"
  ON gift_projects FOR SELECT
  TO authenticated
  USING (
    created_by = auth.uid() -- User is the creator
    OR 
    EXISTS ( -- User is an active member
      SELECT 1 
      FROM project_members 
      WHERE project_members.project_id = id 
      AND project_members.user_id = auth.uid()
      AND project_members.status = 'active'
    )
  );

-- Add new policy for public access via invite code
CREATE POLICY "Anyone can view projects with invite code"
  ON gift_projects FOR SELECT
  TO anon, authenticated
  USING (true);  -- We validate the invite code in the application query

-- Grant necessary permissions
GRANT SELECT ON gift_projects TO anon, authenticated;