/*
  # Add project status columns

  1. Changes
    - Add voting_closed boolean column to gift_projects
    - Add completed_at timestamp column to gift_projects
    - Add trigger to prevent voting when voting is closed or project is completed

  2. Security
    - No changes to RLS policies needed
*/

-- Add new columns to gift_projects
ALTER TABLE gift_projects
  ADD COLUMN voting_closed boolean DEFAULT false,
  ADD COLUMN completed_at timestamptz;

-- Create a function to check if voting is allowed
CREATE OR REPLACE FUNCTION check_voting_allowed()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM gift_projects gp
    JOIN gift_suggestions gs ON gs.project_id = gp.id
    WHERE gs.id = NEW.suggestion_id
    AND (gp.voting_closed = true OR gp.status = 'completed')
  ) THEN
    RAISE EXCEPTION 'Voting is closed for this project';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to prevent voting when closed
CREATE TRIGGER enforce_voting_allowed
  BEFORE INSERT OR UPDATE ON votes
  FOR EACH ROW
  EXECUTE FUNCTION check_voting_allowed();