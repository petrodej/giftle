-- Drop existing policy for anonymous access
DROP POLICY IF EXISTS "View projects by invite code" ON gift_projects;

-- Create new policy that explicitly checks invite code
CREATE POLICY "View projects by invite code"
  ON gift_projects FOR SELECT
  TO anon, authenticated
  USING (
    -- Allow access if invite code matches
    invite_code = COALESCE(
      current_setting('request.query.invite_code', true)::text,
      current_setting('request.jwt.claim.invite_code', true)::text,
      ''
    )
  );

-- Ensure proper permissions are granted
GRANT SELECT ON gift_projects TO anon, authenticated;