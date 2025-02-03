/*
  # Update project members table structure
  
  1. Changes
    - Drop existing primary key
    - Make user_id nullable
    - Add email column
    - Add composite primary key
    - Add check constraint for user identification
    
  2. Security
    - Maintains existing RLS policies
*/

-- First drop the primary key constraint
ALTER TABLE project_members 
  DROP CONSTRAINT IF EXISTS project_members_pkey;

-- Make user_id nullable and add email column if not exists
DO $$ 
BEGIN
  ALTER TABLE project_members 
    ALTER COLUMN user_id DROP NOT NULL;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'project_members' AND column_name = 'email'
  ) THEN
    ALTER TABLE project_members ADD COLUMN email text;
  END IF;
END $$;

-- Create a unique index for project membership
CREATE UNIQUE INDEX project_members_unique_membership_idx 
  ON project_members (project_id, email) 
  WHERE email IS NOT NULL;

CREATE UNIQUE INDEX project_members_unique_user_idx 
  ON project_members (project_id, user_id) 
  WHERE user_id IS NOT NULL;

-- Add constraint to ensure either user_id or email is present
ALTER TABLE project_members
  ADD CONSTRAINT project_members_user_or_email_check 
  CHECK (
    (user_id IS NOT NULL) OR (email IS NOT NULL)
  );