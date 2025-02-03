-- Create a table for application settings
CREATE TABLE IF NOT EXISTS app_settings (
  key text PRIMARY KEY,
  value text NOT NULL
);

-- Insert the Resend API key and base URL
INSERT INTO app_settings (key, value)
VALUES 
  ('resend_key', 're_SpndzDav_PwEmiXpFw5gFrPn1yS2rXPLR'),
  ('base_url', 'https://giftle.stackblitz.io')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- Enable RLS
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- Create policy to allow reading settings
CREATE POLICY "Allow reading settings"
  ON app_settings FOR SELECT
  TO authenticated
  USING (true);

-- Create function to get setting
CREATE OR REPLACE FUNCTION get_setting(setting_key text)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT value FROM app_settings WHERE key = setting_key;
$$;

-- Update the notify_new_member function to use the new get_setting function
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

  -- Send email using Resend API
  PERFORM http((
    'POST',
    'https://api.resend.com/emails',
    ARRAY[
      ('Content-Type', 'application/json')::http_header,
      ('Authorization', format('Bearer %s', get_setting('resend_key')))::http_header
    ],
    request_body
  )::http_request);

  RETURN NEW;
END;
$$;