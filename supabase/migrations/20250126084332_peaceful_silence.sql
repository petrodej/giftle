/*
  # Fix recursive policy for gift projects

  1. Changes
    - Drop the recursive policy that was causing infinite recursion
    - Create new, simplified policies for gift projects that avoid recursion
    - Separate policies for different operations for better control

  2. Security
    - Maintain security by ensuring users can only access their own projects
    - Allow project members to view projects they're part of
    - Allow project creators to manage their projects
*/

-- Drop the problematic policy
DROP POLICY IF EXISTS "Creators can manage recurring projects" ON gift_projects;

-- Create separate policies for different operations
CREATE POLICY "Users can view their own projects"
  ON gift_projects FOR SELECT
  TO authenticated
  USING (
    created_by = auth.uid() OR
    id IN (
      SELECT project_id FROM project_members
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create projects"
  ON gift_projects FOR INSERT
  TO authenticated
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "Creators can update their projects"
  ON gift_projects FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "Creators can delete their projects"
  ON gift_projects FOR DELETE
  TO authenticated
  USING (created_by = auth.uid());