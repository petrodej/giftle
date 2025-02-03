/*
  # Fix RLS policies for votes table
  
  1. Changes
    - Drop existing policies
    - Add new policies for votes table that properly handle medal-based voting
    
  2. Security
    - Allow members to view all votes for their projects
    - Allow members to vote on suggestions in their projects
    - Ensure users can only modify their own votes
*/

-- Drop existing policies for votes table
DROP POLICY IF EXISTS "Members can view votes" ON votes;
DROP POLICY IF EXISTS "Members can vote" ON votes;

-- Create new policies for votes table
CREATE POLICY "View project votes"
  ON votes FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM gift_suggestions gs
      JOIN project_members pm ON pm.project_id = gs.project_id
      WHERE gs.id = votes.suggestion_id
      AND pm.user_id = auth.uid()
      AND pm.status = 'active'
    )
  );

CREATE POLICY "Cast votes"
  ON votes
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- User must be an active member of the project
    EXISTS (
      SELECT 1 
      FROM gift_suggestions gs
      JOIN project_members pm ON pm.project_id = gs.project_id
      WHERE gs.id = votes.suggestion_id
      AND pm.user_id = auth.uid()
      AND pm.status = 'active'
    )
    AND
    -- User can only vote as themselves
    auth.uid() = user_id
  );

CREATE POLICY "Update own votes"
  ON votes
  FOR UPDATE
  TO authenticated
  USING (
    -- Can only update own votes
    auth.uid() = user_id
  )
  WITH CHECK (
    -- Can only update own votes
    auth.uid() = user_id
  );

CREATE POLICY "Delete own votes"
  ON votes
  FOR DELETE
  TO authenticated
  USING (
    -- Can only delete own votes
    auth.uid() = user_id
  );