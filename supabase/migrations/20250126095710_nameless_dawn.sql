/*
  # Add pending invitations support
  
  1. New Tables
    - `pending_invitations`
      - `id` (uuid, primary key)
      - `project_id` (uuid, references gift_projects)
      - `email` (text)
      - `invite_code` (text)
      - `created_at` (timestamptz)
      - `status` (text)
      
  2. Security
    - Enable RLS on `pending_invitations` table
    - Add policies for project admins to manage invitations
*/

-- Create pending invitations table
CREATE TABLE pending_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid REFERENCES gift_projects(id) ON DELETE CASCADE,
  email text NOT NULL,
  invite_code text NOT NULL,
  created_at timestamptz DEFAULT now(),
  status text DEFAULT 'pending',
  UNIQUE(project_id, email)
);

-- Enable RLS
ALTER TABLE pending_invitations ENABLE ROW LEVEL SECURITY;

-- Policies for pending invitations
CREATE POLICY "Project admins can manage invitations"
  ON pending_invitations
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM project_members
      WHERE project_members.project_id = pending_invitations.project_id
      AND project_members.user_id = auth.uid()
      AND project_members.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM project_members
      WHERE project_members.project_id = pending_invitations.project_id
      AND project_members.user_id = auth.uid()
      AND project_members.role = 'admin'
    )
  );

-- Add index for faster lookups
CREATE INDEX pending_invitations_email_idx ON pending_invitations(email);
CREATE INDEX pending_invitations_invite_code_idx ON pending_invitations(invite_code);