/*
  # Add budget range to gift projects

  1. Changes
    - Add min_budget and max_budget columns to gift_projects table
    - Add budget_type column to specify if budget is per person or total

  2. Security
    - Maintain existing RLS policies
*/

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'gift_projects' AND column_name = 'min_budget'
  ) THEN
    ALTER TABLE gift_projects 
      ADD COLUMN min_budget decimal(10,2),
      ADD COLUMN max_budget decimal(10,2),
      ADD COLUMN budget_type text DEFAULT 'per_person' CHECK (budget_type IN ('per_person', 'total'));
  END IF;
END $$;