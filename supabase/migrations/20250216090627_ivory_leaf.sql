-- Drop existing join_project function
DROP FUNCTION IF EXISTS join_project(uuid, text);

-- Create improved join_project function with better error handling
CREATE OR REPLACE FUNCTION join_project(project_id uuid, invite_code text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _user_id uuid;
  _email text;
  _log_id uuid;
  _project_exists boolean;
BEGIN
  -- Get current user info
  _user_id := auth.uid();
  _email := auth.email();

  -- Create detailed log entry
  INSERT INTO pending_notifications (
    email,
    project_id,
    status,
    metadata
  ) VALUES (
    _email,
    project_id,
    'debug',
    jsonb_build_object(
      'function', 'join_project',
      'user_id', _user_id,
      'email', _email,
      'invite_code', invite_code,
      'start_time', now()
    )
  ) RETURNING id INTO _log_id;

  -- Verify user is authenticated
  IF _user_id IS NULL OR _email IS NULL THEN
    UPDATE pending_notifications
    SET 
      status = 'error',
      error_message = 'User must be authenticated to join project',
      processed_at = now()
    WHERE id = _log_id;
    
    RAISE EXCEPTION 'User must be authenticated to join project';
  END IF;

  -- Check if project exists and has matching invite code
  SELECT EXISTS (
    SELECT 1 
    FROM gift_projects 
    WHERE id = project_id 
    AND invite_code = join_project.invite_code
  ) INTO _project_exists;

  IF NOT _project_exists THEN
    UPDATE pending_notifications
    SET 
      status = 'error',
      error_message = 'Invalid project or invite code',
      processed_at = now()
    WHERE id = _log_id;
    
    RAISE EXCEPTION 'Invalid project or invite code';
  END IF;

  -- Insert new membership, handling conflicts
  BEGIN
    INSERT INTO project_members (
      project_id,
      email,
      user_id,
      status,
      role
    ) 
    VALUES (
      project_id,
      _email,
      _user_id,
      'active',
      'member'
    )
    ON CONFLICT (project_id, email) 
    DO UPDATE SET
      user_id = EXCLUDED.user_id,
      status = 'active';

    -- Log success
    UPDATE pending_notifications
    SET 
      status = 'success',
      processed_at = now(),
      metadata = jsonb_build_object(
        'function', 'join_project',
        'user_id', _user_id,
        'email', _email,
        'invite_code', invite_code,
        'start_time', (metadata->>'start_time')::timestamptz,
        'end_time', now(),
        'action', 'upsert'
      )
    WHERE id = _log_id;

  EXCEPTION WHEN OTHERS THEN
    -- Log error details
    UPDATE pending_notifications
    SET 
      status = 'error',
      error_message = SQLERRM,
      processed_at = now(),
      metadata = jsonb_build_object(
        'function', 'join_project',
        'user_id', _user_id,
        'email', _email,
        'invite_code', invite_code,
        'start_time', (metadata->>'start_time')::timestamptz,
        'end_time', now(),
        'error_code', SQLSTATE,
        'error_detail', SQLERRM
      )
    WHERE id = _log_id;
    
    RAISE;
  END;
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION join_project TO authenticated;