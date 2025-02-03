-- First ensure the http extension exists and is up to date
DROP EXTENSION IF EXISTS http;
CREATE EXTENSION http WITH SCHEMA extensions;

-- Create a function to send notifications that uses the correct http function signature
CREATE OR REPLACE FUNCTION notify_new_member_v5()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  project_info RECORD;
  invite_url TEXT;
  request_body TEXT;
BEGIN
  -- Get project information
  SELECT recipient_name, invite_code
  INTO project_info
  FROM gift_projects
  WHERE id = NEW.project_id;

  -- Construct invite URL
  invite_url := current_setting('app.settings.base_url', true) || '/join/' || project_info.invite_code;

  -- Prepare request body
  request_body := jsonb_build_object(
    'to', NEW.email,
    'subject', 'You''ve been invited to a Giftle project!',
    'html', format(
      'You''ve been invited to help choose a gift for %s! ' ||
      '<br><br>' ||
      'Click here to join: <a href="%s">%s</a>' ||
      '<br><br>' ||
      'If you don''t have a Giftle account yet, you''ll be able to create one when you click the link.',
      project_info.recipient_name,
      invite_url,
      invite_url
    )
  )::text;

  -- Send email notification using http extension with simplified parameters
  PERFORM extensions.http(
    'POST',
    current_setting('app.settings.notify_url', true),
    ARRAY[
      ROW('Content-Type', 'application/json')::extensions.http_header,
      ROW('Authorization', format('Bearer %s', current_setting('app.settings.notify_key', true)))::extensions.http_header
    ]::extensions.http_header[],
    request_body
  );

  RETURN NEW;
END;
$$;

-- Drop old trigger and function
DROP TRIGGER IF EXISTS send_member_invite_v4 ON project_members;
DROP FUNCTION IF EXISTS notify_new_member_v4();

-- Create new trigger
CREATE TRIGGER send_member_invite_v5
  AFTER INSERT ON project_members
  FOR EACH ROW
  WHEN (NEW.status = 'pending' AND NEW.email IS NOT NULL)
  EXECUTE FUNCTION notify_new_member_v5();

-- Ensure proper permissions
GRANT USAGE ON SCHEMA extensions TO authenticated;