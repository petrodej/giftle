/*
  # Fix member invitations constraints

  1. Changes
    - Drop existing indexes that might conflict
    - Create new composite unique constraint for project_members
    - Update RLS policies for better security
*/

-- First, drop existing indexes that might conflict
DROP INDEX IF EXISTS project_members_unique_membership_idx;
DROP INDEX IF EXISTS project_members_unique_user_idx;

-- Create new composite unique constraint
ALTER TABLE project_members
  ADD CONSTRAINT project_members_project_email_unique 
  UNIQUE (project_id, email);

-- Update RLS policies for better security
DROP POLICY IF EXISTS "Project creators can add members" ON project_members;
DROP POLICY IF EXISTS "Anyone can view project members" ON project_members;

-- Create new policies
CREATE POLICY "Members can view project members"
  ON project_members FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM project_members pm
      WHERE pm.project_id = project_members.project_id
      AND pm.user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage project members"
  ON project_members
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM project_members pm
      WHERE pm.project_id = project_members.project_id
      AND pm.user_id = auth.uid()
      AND pm.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM project_members pm
      WHERE pm.project_id = project_members.project_id
      AND pm.user_id = auth.uid()
      AND pm.role = 'admin'
    )
  );

CREATE POLICY "Users can join projects"
  ON project_members
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.email() = email
  );