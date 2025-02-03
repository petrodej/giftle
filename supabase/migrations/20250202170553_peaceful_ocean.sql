-- Drop existing trigger and function
DROP TRIGGER IF EXISTS send_member_invite ON project_members;
DROP FUNCTION IF EXISTS notify_new_member();

-- Update app settings with Edge Function URL
INSERT INTO app_settings (key, value)
VALUES ('edge_function_url', 'https://zqedbnnolhizvogksovc.supabase.co/functions/v1/send-email')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- Create new notification function using Edge Function
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

  -- Send email using Edge Function
  PERFORM http(
    'POST',
    get_setting('edge_function_url'),
    ARRAY[
      ROW('Content-Type', 'application/json')::http_header,
      ROW('Authorization', 'Bearer ' || current_setting('request.jwt.claim.role', true))::http_header
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