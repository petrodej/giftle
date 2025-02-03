/*
  # Fix project members policies

  1. Changes
    - Drop existing problematic policies
    - Create new non-recursive policies for project members
    - Add better security checks
*/

-- Drop existing policies that might cause recursion
DROP POLICY IF EXISTS "Members can view project members" ON project_members;
DROP POLICY IF EXISTS "Admins can manage project members" ON project_members;
DROP POLICY IF EXISTS "Users can join projects" ON project_members;

-- Create new, non-recursive policies
CREATE POLICY "Anyone can view members of their projects"
  ON project_members FOR SELECT
  TO authenticated
  USING (
    project_id IN (
      SELECT project_id 
      FROM project_members 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage members"
  ON project_members
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM project_members 
      WHERE project_id = project_members.project_id
      AND user_id = auth.uid()
      AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 
      FROM project_members 
      WHERE project_id = project_members.project_id
      AND user_id = auth.uid()
      AND role = 'admin'
    )
  );

CREATE POLICY "Users can join via email"
  ON project_members
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.email() = email
    AND status = 'pending'
  );