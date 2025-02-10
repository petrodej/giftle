-- Add metadata and error_message columns to pending_notifications
ALTER TABLE pending_notifications
  ADD COLUMN IF NOT EXISTS metadata jsonb,
  ADD COLUMN IF NOT EXISTS error_message text;