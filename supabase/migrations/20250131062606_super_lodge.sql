-- First ensure the http extension exists
CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;

-- Create http_header type if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'http_header') THEN
    CREATE TYPE http_header AS (
      field text,
      value text
    );
  END IF;
END$$;

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS send_member_invite ON project_members;
DROP FUNCTION IF EXISTS notify_new_member();

-- Create a function to send notifications using Resend
CREATE OR REPLACE FUNCTION notify_new_member()
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
  invite_url := get_setting('base_url') || '/join/' || project_info.invite_code;

  -- Prepare request body
  request_body := jsonb_build_object(
    'from', 'onboarding@resend.dev',
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

  -- Send email using Resend API with standard http function
  PERFORM extensions.http(
    'POST',
    'https://api.resend.com/emails',
    ARRAY[
      ROW('Content-Type', 'application/json')::http_header,
      ROW('Authorization', 'Bearer ' || get_setting('resend_key'))::http_header
    ],
    request_body
  );

  RETURN NEW;
END;
$$;

-- Create trigger for new pending members
CREATE TRIGGER send_member_invite
  AFTER INSERT ON project_members
  FOR EACH ROW
  WHEN (NEW.status = 'pending' AND NEW.email IS NOT NULL)
  EXECUTE FUNCTION notify_new_member();

-- Ensure proper permissions
GRANT USAGE ON SCHEMA extensions TO authenticated;