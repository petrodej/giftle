/*
  # Initial Giftle Database Schema

  1. New Tables
    - `profiles`
      - User profiles with names and avatars
    - `gift_projects`
      - Group gift projects with recipient info and dates
    - `project_members`
      - Members of each gift project
    - `gift_suggestions`
      - Suggested gifts for each project
    - `votes`
      - Votes on gift suggestions
    
  2. Security
    - RLS enabled on all tables
    - Policies for authenticated users to:
      - Read and update their own profile
      - Create and read gift projects
      - Join projects and suggest gifts
      - Vote on suggestions
*/

-- Create profiles table
CREATE TABLE profiles (
  id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  email text NOT NULL,
  full_name text,
  avatar_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create gift projects table
CREATE TABLE gift_projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_by uuid REFERENCES profiles(id),
  recipient_name text NOT NULL,
  birth_date date,
  interests text[],
  created_at timestamptz DEFAULT now(),
  project_date date NOT NULL,
  status text DEFAULT 'active',
  selected_gift_id uuid,
  purchaser_id uuid REFERENCES profiles(id),
  invite_code text UNIQUE DEFAULT encode(gen_random_bytes(6), 'base64')
);

-- Create project members table
CREATE TABLE project_members (
  project_id uuid REFERENCES gift_projects(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at timestamptz DEFAULT now(),
  role text DEFAULT 'member',
  PRIMARY KEY (project_id, user_id)
);

-- Create gift suggestions table
CREATE TABLE gift_suggestions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid REFERENCES gift_projects(id) ON DELETE CASCADE,
  suggested_by uuid REFERENCES profiles(id),
  title text NOT NULL,
  description text,
  price decimal(10,2),
  url text,
  created_at timestamptz DEFAULT now()
);

-- Create votes table
CREATE TABLE votes (
  suggestion_id uuid REFERENCES gift_suggestions(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (suggestion_id, user_id)
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE gift_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE gift_suggestions ENABLE ROW LEVEL SECURITY;
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can read their own profile"
  ON profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- Gift projects policies
CREATE POLICY "Anyone can create gift projects"
  ON gift_projects FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Members can view their projects"
  ON gift_projects FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM project_members
      WHERE project_id = gift_projects.id
      AND user_id = auth.uid()
    )
  );

-- Project members policies
CREATE POLICY "Members can view project members"
  ON project_members FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM project_members pm
      WHERE pm.project_id = project_members.project_id
      AND pm.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can join projects"
  ON project_members FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Gift suggestions policies
CREATE POLICY "Members can view suggestions"
  ON gift_suggestions FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM project_members
      WHERE project_id = gift_suggestions.project_id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "Members can add suggestions"
  ON gift_suggestions FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM project_members
      WHERE project_id = gift_suggestions.project_id
      AND user_id = auth.uid()
    )
  );

-- Votes policies
CREATE POLICY "Members can view votes"
  ON votes FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM gift_suggestions gs
      JOIN project_members pm ON pm.project_id = gs.project_id
      WHERE gs.id = votes.suggestion_id
      AND pm.user_id = auth.uid()
    )
  );

CREATE POLICY "Members can vote"
  ON votes FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM gift_suggestions gs
      JOIN project_members pm ON pm.project_id = gs.project_id
      WHERE gs.id = votes.suggestion_id
      AND pm.user_id = auth.uid()
    )
  );