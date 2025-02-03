-- Create a table for application settings if it doesn't exist
CREATE TABLE IF NOT EXISTS app_settings (
  key text PRIMARY KEY,
  value text NOT NULL
);

-- Insert or update the settings
INSERT INTO app_settings (key, value)
VALUES 
  ('resend_key', 're_SpndzDav_PwEmiXpFw5gFrPn1yS2rXPLR'),
  ('base_url', 'https://giftle.stackblitz.io')
ON CONFLICT (key) DO UPDATE 
SET value = EXCLUDED.value;

-- Enable RLS
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Allow reading settings" ON app_settings;

-- Create policy to allow reading settings
CREATE POLICY "Allow reading settings"
  ON app_settings FOR SELECT
  TO authenticated
  USING (true);

-- Create or replace function to get setting
CREATE OR REPLACE FUNCTION get_setting(setting_key text)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT value FROM app_settings WHERE key = setting_key;
$$;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO postgres, authenticated, anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres;
GRANT SELECT ON app_settings TO authenticated;