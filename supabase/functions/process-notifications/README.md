# Process Notifications Edge Function

This Edge Function processes pending email notifications from the `pending_notifications` table.

## Setup

1. Set the required secrets in your Supabase project:
   ```bash
   supabase secrets set RESEND_API_KEY=your_resend_api_key
   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
   ```

2. Deploy the function:
   ```bash
   supabase functions deploy process-notifications
   ```

## Usage

Send a POST request to trigger notification processing:

```bash
curl -X POST https://your-project.supabase.co/functions/v1/process-notifications
```

### Example Response

Success:
```json
{
  "success": true,
  "results": [
    {
      "id": "notification_id",
      "success": true,
      "emailId": "email_id"
    }
  ]
}
```

Error:
```json
{
  "success": false,
  "error": "Error message"
}
```

## Monitoring

You can monitor the notification status in the `pending_notifications` table:

- `status`: Can be 'pending', 'sent', or 'failed'
- `processed_at`: Timestamp when the notification was processed