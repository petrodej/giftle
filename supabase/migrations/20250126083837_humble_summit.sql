/*
  # Add advanced features

  1. New Columns
    - Add to gift_projects:
      - parent_project_id (uuid, references gift_projects)
      - is_recurring (boolean)
      - next_occurrence_date (timestamptz)
    - Add to gift_suggestions:
      - is_ai_generated (boolean)
      - confidence_score (decimal)
      - source_suggestion_id (uuid, references gift_suggestions)

  2. Changes
    - Add foreign key constraints for new reference columns
    - Set default values for new boolean columns

  3. Security
    - Update RLS policies to handle recurring projects
    - Add policies for AI-generated suggestions
*/

-- Add new columns to gift_projects
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'gift_projects' AND column_name = 'parent_project_id'
  ) THEN
    ALTER TABLE gift_projects 
      ADD COLUMN parent_project_id uuid REFERENCES gift_projects(id),
      ADD COLUMN is_recurring boolean DEFAULT false,
      ADD COLUMN next_occurrence_date timestamptz;
  END IF;
END $$;

-- Add new columns to gift_suggestions
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'gift_suggestions' AND column_name = 'is_ai_generated'
  ) THEN
    ALTER TABLE gift_suggestions 
      ADD COLUMN is_ai_generated boolean DEFAULT false,
      ADD COLUMN confidence_score decimal(4,3),
      ADD COLUMN source_suggestion_id uuid REFERENCES gift_suggestions(id);
  END IF;
END $$;

-- Add policy for recurring projects
CREATE POLICY "Creators can manage recurring projects"
  ON gift_projects
  FOR ALL
  TO authenticated
  USING (
    created_by = auth.uid() OR 
    parent_project_id IN (
      SELECT id FROM gift_projects WHERE created_by = auth.uid()
    )
  )
  WITH CHECK (
    created_by = auth.uid() OR 
    parent_project_id IN (
      SELECT id FROM gift_projects WHERE created_by = auth.uid()
    )
  );

-- Add policy for AI-generated suggestions
CREATE POLICY "Members can manage AI suggestions"
  ON gift_suggestions
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM project_members
      WHERE project_members.project_id = gift_suggestions.project_id
      AND project_members.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM project_members
      WHERE project_members.project_id = gift_suggestions.project_id
      AND project_members.user_id = auth.uid()
    )
  );