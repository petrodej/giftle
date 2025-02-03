/*
  # Fix project and member policies - Final Attempt

  1. Changes
    - Completely restructure policies to avoid any recursion
    - Use direct checks without subqueries where possible
    - Separate member access logic from project access logic
    - Add status checks for active members only
*/

-- Drop all existing policies
DROP POLICY IF EXISTS "View projects" ON gift_projects;
DROP POLICY IF EXISTS "Create projects" ON gift_projects;
DROP POLICY IF EXISTS "Update projects" ON gift_projects;
DROP POLICY IF EXISTS "Delete projects" ON gift_projects;
DROP POLICY IF EXISTS "View members" ON project_members;
DROP POLICY IF EXISTS "Insert members" ON project_members;
DROP POLICY IF EXISTS "Update members" ON project_members;
DROP POLICY IF EXISTS "Delete members" ON project_members;

-- Create new project_members policies first
CREATE POLICY "View project members"
  ON project_members FOR SELECT
  TO authenticated
  USING (true);  -- Allow all authenticated users to view members

CREATE POLICY "Insert project members"
  ON project_members FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Allow project creators to add members
    EXISTS (
      SELECT 1 
      FROM gift_projects 
      WHERE id = project_members.project_id 
      AND created_by = auth.uid()
    )
    OR 
    -- Allow users to accept their own invitations
    (email = auth.email() AND status = 'pending')
  );

CREATE POLICY "Update project members"
  ON project_members FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM gift_projects 
      WHERE id = project_members.project_id 
      AND created_by = auth.uid()
    )
  );

CREATE POLICY "Delete project members"
  ON project_members FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM gift_projects 
      WHERE id = project_members.project_id 
      AND created_by = auth.uid()
    )
  );

-- Create new gift_projects policies
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

CREATE POLICY "Insert projects"
  ON gift_projects FOR INSERT
  TO authenticated
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "Update projects"
  ON gift_projects FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid());

CREATE POLICY "Delete projects"
  ON gift_projects FOR DELETE
  TO authenticated
  USING (created_by = auth.uid());