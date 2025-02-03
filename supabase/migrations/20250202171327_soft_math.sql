-- Check all notifications with their status
SELECT 
  pn.id,
  pn.email,
  pn.status,
  pn.created_at,
  pn.processed_at,
  gp.recipient_name
FROM pending_notifications pn
JOIN gift_projects gp ON gp.id = pn.project_id
ORDER BY pn.created_at DESC;