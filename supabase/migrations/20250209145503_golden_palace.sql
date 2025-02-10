-- Drop existing policies
DROP POLICY IF EXISTS "Allow service role full access to notifications" ON pending_notifications;

-- Create new RLS policies for pending_notifications
CREATE POLICY "Allow authenticated users to insert notifications"
  ON pending_notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to view notifications"
  ON pending_notifications
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow authenticated users to update notifications"
  ON pending_notifications
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Grant necessary permissions
GRANT ALL ON pending_notifications TO authenticated;