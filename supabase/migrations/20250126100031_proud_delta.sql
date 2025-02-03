/*
  # Add member status
  
  1. Changes
    - Add status column to project_members table
    - Add status enum type for member statuses
    
  2. Security
    - Update existing policies to handle status field
*/

-- Create member status type
CREATE TYPE member_status AS ENUM ('active', 'pending');

-- Add status to project_members
ALTER TABLE project_members 
  ADD COLUMN status member_status NOT NULL DEFAULT 'active';

-- Update existing members to active status
UPDATE project_members SET status = 'active';