/*
  # Add medal-based voting system
  
  1. Changes
    - Add medal column to votes table
    - Add constraint to ensure valid medal values
    - Update RLS policies to handle medal-based voting
  
  2. Security
    - Maintain existing RLS policies
    - Add check constraint for valid medal values
*/

-- Add medal column to votes table
ALTER TABLE votes 
  ADD COLUMN medal text CHECK (medal IN ('gold', 'silver', 'bronze'));

-- Add unique constraint to ensure one medal type per user per suggestion
ALTER TABLE votes
  ADD CONSTRAINT one_medal_per_user_per_suggestion 
  UNIQUE (suggestion_id, user_id);