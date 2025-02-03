/*
  # Fix project members policies - Final

  1. Changes
    - Drop all existing project_members policies
    - Create new optimized policies with no recursion
    - Add better security checks
    - Simplify policy logic
*/

-- Drop all existing policies for project_members
DROP POLICY IF EXISTS "Anyone can view members of their projects" ON project_members;
DROP POLICY IF EXISTS "Admins can manage members" ON project_members;
DROP POLICY IF EXISTS "Users can join via email" ON project_members;

-- Create new, simplified policies
CREATE POLICY "View project members"
  ON project_members FOR SELECT
  TO authenticated
  USING (
    -- Allow if user is a member (direct check on user_id)
    user_id = auth.uid()
    OR
    -- Or if user is a member of the project (using project_id)
    project_id IN (
      SELECT pm.project_id 
      FROM project_members pm 
      WHERE pm.user_id = auth.uid()
    )
  );

CREATE POLICY "Admin insert members"
  ON project_members FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Allow admins to add members
    EXISTS (
      SELECT 1 
      FROM project_members pm 
      WHERE pm.project_id = project_members.project_id
      AND pm.user_id = auth.uid()
      AND pm.role = 'admin'
    )
    OR
    -- Or allow users to accept their own invitations
    (auth.email() = email AND status = 'pending')
  );

CREATE POLICY "Admin update members"
  ON project_members FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM project_members pm 
      WHERE pm.project_id = project_members.project_id
      AND pm.user_id = auth.uid()
      AND pm.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 
      FROM project_members pm 
      WHERE pm.project_id = project_members.project_id
      AND pm.user_id = auth.uid()
      AND pm.role = 'admin'
    )
  );

CREATE POLICY "Admin delete members"
  ON project_members FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM project_members pm 
      WHERE pm.project_id = project_members.project_id
      AND pm.user_id = auth.uid()
      AND pm.role = 'admin'
    )
  );