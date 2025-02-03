/*
  # Add email column to project_members
  
  1. Changes
    - Add email column to project_members table
    - Add index for faster email lookups
    
  2. Security
    - No changes to existing policies needed
*/

-- Add email column to project_members
ALTER TABLE project_members 
  ADD COLUMN email text;

-- Add index for faster lookups
CREATE INDEX project_members_email_idx ON project_members(email);

-- Update existing members with their emails
UPDATE project_members pm
SET email = p.email
FROM profiles p
WHERE pm.user_id = p.id;