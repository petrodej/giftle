-- Create function to assign random purchaser
CREATE OR REPLACE FUNCTION assign_random_purchaser(project_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  selected_user_id uuid;
  result json;
BEGIN
  -- Get random active member
  SELECT user_id INTO selected_user_id
  FROM project_members
  WHERE project_id = $1
    AND status = 'active'
    AND user_id IS NOT NULL
  ORDER BY random()
  LIMIT 1;

  -- Update project with selected purchaser
  UPDATE gift_projects
  SET purchaser_id = selected_user_id
  WHERE id = $1;

  -- Return result
  SELECT json_build_object(
    'purchaser_id', selected_user_id
  ) INTO result;

  RETURN result;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION assign_random_purchaser TO authenticated;