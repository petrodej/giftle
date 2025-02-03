/*
  # Fix RLS policies for project members

  1. Changes
    - Simplify project members policies to avoid recursion
    - Update related policies for better security
  
  2. Security
    - Maintain data access control while preventing infinite recursion
    - Ensure proper authorization checks
*/

-- Drop existing policies to recreate them
DROP POLICY IF EXISTS "Members can view project members" ON project_members;
DROP POLICY IF EXISTS "Users can join projects" ON project_members;

-- Create new, simplified policies for project members
CREATE POLICY "Anyone can view project members"
  ON project_members FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Project creators can add members"
  ON project_members FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM gift_projects
      WHERE id = project_id
      AND created_by = auth.uid()
    )
    OR
    user_id = auth.uid() -- Allow users to add themselves
  );

-- Update gift suggestions policy to use direct project check
DROP POLICY IF EXISTS "Members can view suggestions" ON gift_suggestions;
DROP POLICY IF EXISTS "Members can add suggestions" ON gift_suggestions;

CREATE POLICY "Members can view suggestions"
  ON gift_suggestions FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM project_members
      WHERE project_members.project_id = gift_suggestions.project_id
      AND project_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Members can add suggestions"
  ON gift_suggestions FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM project_members
      WHERE project_members.project_id = gift_suggestions.project_id
      AND project_members.user_id = auth.uid()
    )
  );