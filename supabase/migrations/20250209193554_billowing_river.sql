/*
  # Prevent duplicate emails in projects

  1. Changes
    - Add unique constraint to prevent duplicate emails in a project
    - Add trigger to prevent email conflicts when updating user_id
  
  2. Security
    - Ensures data integrity by preventing duplicate memberships
*/

-- First, clean up any existing duplicates (keep the most recent one)
DELETE FROM project_members a
WHERE EXISTS (
  SELECT 1
  FROM project_members b
  WHERE b.project_id = a.project_id
  AND b.email = a.email
  AND b.joined_at > a.joined_at
);

-- Add unique constraint for project members
ALTER TABLE project_members
  DROP CONSTRAINT IF EXISTS project_members_project_email_unique,
  ADD CONSTRAINT project_members_project_email_unique 
  UNIQUE (project_id, email)
  DEFERRABLE INITIALLY DEFERRED;

-- Create trigger function to prevent email conflicts
CREATE OR REPLACE FUNCTION check_member_email_conflicts()
RETURNS TRIGGER AS $$
DECLARE
  user_email text;
BEGIN
  -- If we're updating user_id and the email exists
  IF TG_OP = 'UPDATE' AND NEW.user_id IS NOT NULL THEN
    -- Get the user's email
    SELECT email INTO user_email
    FROM auth.users 
    WHERE id = NEW.user_id
    LIMIT 1;

    -- Update email field
    NEW.email := user_email;
    
    -- If this would create a duplicate, raise an error
    IF EXISTS (
      SELECT 1 
      FROM project_members
      WHERE project_id = NEW.project_id 
      AND email = NEW.email
      AND (
        (TG_OP = 'UPDATE' AND project_id != OLD.project_id) OR
        TG_OP = 'INSERT'
      )
    ) THEN
      RAISE EXCEPTION 'User is already a member of this project';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS check_member_email_conflicts ON project_members;

-- Create trigger
CREATE TRIGGER check_member_email_conflicts
  BEFORE INSERT OR UPDATE ON project_members
  FOR EACH ROW
  EXECUTE FUNCTION check_member_email_conflicts();