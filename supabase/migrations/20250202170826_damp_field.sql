-- Drop all existing email notification triggers and functions
DROP TRIGGER IF EXISTS send_member_invite ON project_members;
DROP TRIGGER IF EXISTS send_member_invite_v2 ON project_members;
DROP TRIGGER IF EXISTS send_member_invite_v3 ON project_members;
DROP TRIGGER IF EXISTS send_member_invite_v4 ON project_members;
DROP TRIGGER IF EXISTS send_member_invite_v5 ON project_members;
DROP TRIGGER IF EXISTS send_member_invite_v6 ON project_members;
DROP TRIGGER IF EXISTS send_member_invite_v7 ON project_members;
DROP TRIGGER IF EXISTS send_member_invite_v8 ON project_members;

DROP FUNCTION IF EXISTS notify_new_member();
DROP FUNCTION IF EXISTS notify_new_member_v2();
DROP FUNCTION IF EXISTS notify_new_member_v3();
DROP FUNCTION IF EXISTS notify_new_member_v4();
DROP FUNCTION IF EXISTS notify_new_member_v5();
DROP FUNCTION IF EXISTS notify_new_member_v6();
DROP FUNCTION IF EXISTS notify_new_member_v7();
DROP FUNCTION IF EXISTS notify_new_member_v8();

-- Create a simple notification tracking table
CREATE TABLE IF NOT EXISTS pending_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  project_id uuid NOT NULL REFERENCES gift_projects(id),
  created_at timestamptz DEFAULT now(),
  processed_at timestamptz,
  status text DEFAULT 'pending',
  CONSTRAINT fk_project FOREIGN KEY (project_id) REFERENCES gift_projects(id) ON DELETE CASCADE
);

-- Enable RLS
ALTER TABLE pending_notifications ENABLE ROW LEVEL SECURITY;

-- Create RLS policy
CREATE POLICY "Allow service role full access to notifications"
  ON pending_notifications
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Create simple trigger function to track pending notifications
CREATE OR REPLACE FUNCTION track_pending_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO pending_notifications (email, project_id)
  VALUES (NEW.email, NEW.project_id);
  RETURN NEW;
END;
$$;

-- Create trigger for new pending members
CREATE TRIGGER track_member_invite
  AFTER INSERT ON project_members
  FOR EACH ROW
  WHEN (NEW.status = 'pending' AND NEW.email IS NOT NULL)
  EXECUTE FUNCTION track_pending_notification();