-- Drop existing function if it exists
DROP FUNCTION IF EXISTS assign_random_purchaser(uuid);

-- Create function to assign random purchaser
CREATE OR REPLACE FUNCTION assign_random_purchaser(input_project_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  selected_user_id uuid;
  result json;
BEGIN
  -- Get random active member using table alias to avoid ambiguity
  SELECT pm.user_id INTO selected_user_id
  FROM project_members pm
  WHERE pm.project_id = input_project_id
    AND pm.status = 'active'
    AND pm.user_id IS NOT NULL
  ORDER BY random()
  LIMIT 1;

  -- Update project with selected purchaser
  UPDATE gift_projects
  SET purchaser_id = selected_user_id
  WHERE id = input_project_id;

  -- Return result
  SELECT json_build_object(
    'purchaser_id', selected_user_id
  ) INTO result;

  RETURN result;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION assign_random_purchaser TO authenticated;