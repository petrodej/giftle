-- Drop existing trigger and function if they exist
DROP TRIGGER IF EXISTS send_member_invite ON project_members;
DROP FUNCTION IF EXISTS notify_new_member();

-- Enable the http extension if not already enabled
CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;

-- Create the email notification function
CREATE OR REPLACE FUNCTION notify_new_member()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  project_info RECORD;
  invite_url TEXT;
  response RECORD;
BEGIN
  -- Get project information
  SELECT recipient_name, invite_code
  INTO project_info
  FROM gift_projects
  WHERE id = NEW.project_id;

  -- Construct invite URL
  invite_url := current_setting('app.settings.base_url', true) || '/join/' || project_info.invite_code;

  -- Send email notification using http extension
  SELECT * FROM extensions.http(
    'POST',
    current_setting('app.settings.notify_url', true),
    jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', concat('Bearer ', current_setting('app.settings.notify_key', true))
    ),
    jsonb_build_object(
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
    )
  ) INTO response;

  RETURN NEW;
END;
$$;

-- Create trigger for new pending members
CREATE TRIGGER send_member_invite
  AFTER INSERT ON project_members
  FOR EACH ROW
  WHEN (NEW.status = 'pending' AND NEW.email IS NOT NULL)
  EXECUTE FUNCTION notify_new_member();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA extensions TO authenticated;