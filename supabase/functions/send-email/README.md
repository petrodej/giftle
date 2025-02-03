# Send Email Edge Function

This Edge Function handles sending emails via Resend.

## Setup

1. Set the `RESEND_API_KEY` secret in your Supabase project:
   ```bash
   supabase secrets set RESEND_API_KEY=your_resend_api_key
   ```

2. Deploy the function:
   ```bash
   supabase functions deploy send-email
   ```

## Usage

Send a POST request to the function endpoint with the following body:

```json
{
  "to": "recipient@example.com",
  "subject": "Email Subject",
  "html": "Email content in HTML format"
}
```

### Example Response

Success:
```json
{
  "success": true,
  "data": {
    "id": "email_id"
  }
}
```

Error:
```json
{
  "success": false,
  "error": "Error message"
}
```

## CORS and Security

The function includes CORS headers to allow requests from any origin. In production, you should update the `corsHeaders` to only allow requests from your application's domain.