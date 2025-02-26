-- Drop existing join_project function
DROP FUNCTION IF EXISTS join_project(uuid, text);

-- Create improved join_project function with logging
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
BEGIN
  -- Get current user info
  _user_id := auth.uid();
  _email := auth.email();

  -- Create log entry
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
      'timestamp', now()
    )
  ) RETURNING id INTO _log_id;

  -- Verify user is authenticated
  IF _user_id IS NULL OR _email IS NULL THEN
    -- Update log
    UPDATE pending_notifications
    SET 
      status = 'error',
      error_message = 'User must be authenticated to join project'
    WHERE id = _log_id;
    
    RAISE EXCEPTION 'User must be authenticated to join project';
  END IF;

  -- Verify invite code
  IF NOT EXISTS (
    SELECT 1 
    FROM gift_projects 
    WHERE id = project_id 
    AND invite_code = join_project.invite_code
  ) THEN
    -- Update log
    UPDATE pending_notifications
    SET 
      status = 'error',
      error_message = 'Invalid invite code'
    WHERE id = _log_id;
    
    RAISE EXCEPTION 'Invalid invite code';
  END IF;

  -- First try to update any existing membership
  UPDATE project_members
  SET 
    user_id = _user_id,
    status = 'active'
  WHERE 
    project_id = join_project.project_id
    AND (
      email = _email
      OR user_id = _user_id
    );

  -- If no rows were updated, insert a new membership
  IF NOT FOUND THEN
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
      );

      -- Update log with success
      UPDATE pending_notifications
      SET 
        status = 'success',
        metadata = metadata || jsonb_build_object(
          'action', 'insert',
          'completed_at', now()
        )
      WHERE id = _log_id;
    EXCEPTION WHEN OTHERS THEN
      -- Update log with error
      UPDATE pending_notifications
      SET 
        status = 'error',
        error_message = SQLERRM,
        metadata = metadata || jsonb_build_object(
          'action', 'insert',
          'error_code', SQLSTATE,
          'completed_at', now()
        )
      WHERE id = _log_id;
      
      RAISE;
    END;
  ELSE
    -- Update log with success
    UPDATE pending_notifications
    SET 
      status = 'success',
      metadata = metadata || jsonb_build_object(
        'action', 'update',
        'completed_at', now()
      )
    WHERE id = _log_id;
  END IF;
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION join_project TO authenticated;