-- Create a function to generate unique invite codes
CREATE OR REPLACE FUNCTION generate_unique_code()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  new_code text;
  code_exists boolean;
BEGIN
  LOOP
    -- Generate a random 8-character code
    new_code := encode(gen_random_bytes(6), 'base64');
    
    -- Check if code exists
    SELECT EXISTS (
      SELECT 1 
      FROM gift_projects 
      WHERE invite_code = new_code
    ) INTO code_exists;
    
    -- Exit loop if code is unique
    EXIT WHEN NOT code_exists;
  END LOOP;
  
  RETURN new_code;
END;
$$;

-- Add RLS policy for the function
GRANT EXECUTE ON FUNCTION generate_unique_code TO authenticated;