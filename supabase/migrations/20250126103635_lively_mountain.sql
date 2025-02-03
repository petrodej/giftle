/*
  # Fix project members policies - Final (Take 2)

  1. Changes
    - Drop all existing project_members policies
    - Create new simplified policies with no recursion
    - Use direct checks instead of subqueries where possible
    - Separate policies by operation type
*/

-- Drop all existing policies for project_members
DROP POLICY IF EXISTS "View project members" ON project_members;
DROP POLICY IF EXISTS "Admin insert members" ON project_members;
DROP POLICY IF EXISTS "Admin update members" ON project_members;
DROP POLICY IF EXISTS "Admin delete members" ON project_members;

-- Create new, simplified policies
CREATE POLICY "Members can view"
  ON project_members FOR SELECT
  TO authenticated
  USING (
    -- Direct check for user's own membership
    user_id = auth.uid()
    OR
    -- Check if user has access to the project
    EXISTS (
      SELECT 1 
      FROM gift_projects gp
      WHERE gp.id = project_members.project_id
      AND gp.created_by = auth.uid()
    )
  );

CREATE POLICY "Members can insert"
  ON project_members FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Allow project creators to add members
    EXISTS (
      SELECT 1 
      FROM gift_projects gp
      WHERE gp.id = project_members.project_id
      AND gp.created_by = auth.uid()
    )
    OR
    -- Allow users to accept their own invitations
    (auth.email() = email AND status = 'pending')
  );

CREATE POLICY "Members can update"
  ON project_members FOR UPDATE
  TO authenticated
  USING (
    -- Only project creators can update members
    EXISTS (
      SELECT 1 
      FROM gift_projects gp
      WHERE gp.id = project_members.project_id
      AND gp.created_by = auth.uid()
    )
  )
  WITH CHECK (
    -- Only project creators can update members
    EXISTS (
      SELECT 1 
      FROM gift_projects gp
      WHERE gp.id = project_members.project_id
      AND gp.created_by = auth.uid()
    )
  );

CREATE POLICY "Members can delete"
  ON project_members FOR DELETE
  TO authenticated
  USING (
    -- Only project creators can delete members
    EXISTS (
      SELECT 1 
      FROM gift_projects gp
      WHERE gp.id = project_members.project_id
      AND gp.created_by = auth.uid()
    )
  );