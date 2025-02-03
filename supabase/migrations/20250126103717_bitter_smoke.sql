/*
  # Fix project and member policies - Final

  1. Changes
    - Drop and recreate all gift_projects policies
    - Drop and recreate all project_members policies
    - Eliminate circular dependencies between tables
    - Use simpler, direct checks
    - Separate policies by operation type
*/

-- Drop all existing policies for both tables
DROP POLICY IF EXISTS "Users can view their own projects" ON gift_projects;
DROP POLICY IF EXISTS "Users can create projects" ON gift_projects;
DROP POLICY IF EXISTS "Creators can update their projects" ON gift_projects;
DROP POLICY IF EXISTS "Creators can delete their projects" ON gift_projects;
DROP POLICY IF EXISTS "Members can view" ON project_members;
DROP POLICY IF EXISTS "Members can insert" ON project_members;
DROP POLICY IF EXISTS "Members can update" ON project_members;
DROP POLICY IF EXISTS "Members can delete" ON project_members;

-- Create new gift_projects policies
CREATE POLICY "View projects"
  ON gift_projects FOR SELECT
  TO authenticated
  USING (
    created_by = auth.uid()
    OR
    id IN (
      SELECT project_id 
      FROM project_members 
      WHERE user_id = auth.uid()
      AND status = 'active'
    )
  );

CREATE POLICY "Create projects"
  ON gift_projects FOR INSERT
  TO authenticated
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "Update projects"
  ON gift_projects FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "Delete projects"
  ON gift_projects FOR DELETE
  TO authenticated
  USING (created_by = auth.uid());

-- Create new project_members policies
CREATE POLICY "View members"
  ON project_members FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR
    project_id IN (
      SELECT id 
      FROM gift_projects 
      WHERE created_by = auth.uid()
    )
  );

CREATE POLICY "Insert members"
  ON project_members FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Project creators can add members
    project_id IN (
      SELECT id 
      FROM gift_projects 
      WHERE created_by = auth.uid()
    )
    OR
    -- Users can accept their own invitations
    (auth.email() = email AND status = 'pending')
  );

CREATE POLICY "Update members"
  ON project_members FOR UPDATE
  TO authenticated
  USING (
    project_id IN (
      SELECT id 
      FROM gift_projects 
      WHERE created_by = auth.uid()
    )
  )
  WITH CHECK (
    project_id IN (
      SELECT id 
      FROM gift_projects 
      WHERE created_by = auth.uid()
    )
  );

CREATE POLICY "Delete members"
  ON project_members FOR DELETE
  TO authenticated
  USING (
    project_id IN (
      SELECT id 
      FROM gift_projects 
      WHERE created_by = auth.uid()
    )
  );