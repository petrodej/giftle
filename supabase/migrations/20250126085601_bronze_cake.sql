/*
  # Fix profile policies

  1. Changes
    - Add policy for users to insert their own profile
    - Fix profile selection policy
  
  2. Security
    - Users can only insert their own profile
    - Users can only view their own profile
*/

-- Drop existing profile policies
DROP POLICY IF EXISTS "Users can read their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;

-- Create new profile policies
CREATE POLICY "Users can manage their own profile"
  ON profiles
  FOR ALL
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);