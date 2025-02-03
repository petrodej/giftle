/*
  # Add email notifications for member invites

  1. New Function
    - Creates a function to send email notifications
    - Uses Supabase's built-in http extension
    - Sends welcome email with project details and join link

  2. Trigger
    - Adds trigger to send email when new pending members are added
    - Only sends for pending members with valid emails
*/

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
BEGIN
  -- Get project information
  SELECT recipient_name, invite_code
  INTO project_info
  FROM gift_projects
  WHERE id = NEW.project_id;

  -- Construct invite URL
  invite_url := current_setting('app.settings.base_url', true) || '/join/' || project_info.invite_code;

  -- Send email notification using http extension
  PERFORM extensions.http((
    'POST',
    current_setting('app.settings.notify_url', true),
    ARRAY[
      http_header('Content-Type', 'application/json'),
      http_header('Authorization', 'Bearer ' || current_setting('app.settings.notify_key', true))
    ],
    'application/json',
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
    )::text
  ));

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