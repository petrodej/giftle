-- Drop any existing duplicate foreign key constraints
ALTER TABLE pending_notifications 
  DROP CONSTRAINT IF EXISTS pending_notifications_project_id_fkey,
  DROP CONSTRAINT IF EXISTS fk_project;

-- Keep only one foreign key constraint
ALTER TABLE pending_notifications
  ADD CONSTRAINT pending_notifications_project_id_fkey 
  FOREIGN KEY (project_id) 
  REFERENCES gift_projects(id) 
  ON DELETE CASCADE;