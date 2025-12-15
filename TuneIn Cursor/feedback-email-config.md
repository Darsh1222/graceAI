# Feedback Email Configuration

## Setup Instructions for darsh@graceai.music

### Option 1: EmailJS (Recommended - Easy Setup)

1. **Create EmailJS Account:**
   - Go to https://www.emailjs.com/
   - Sign up for a free account
   - Create a new service (Gmail, Outlook, etc.)

2. **Configure Email Template:**
   - Template ID: `template_xxxxx`
   - Service ID: `service_xxxxx`
   - Public Key: `your_public_key`

3. **Email Template Content:**
```
Subject: New Feedback from GraceAI App - {{name}}

Name: {{name}}
Email: {{email}}
Timestamp: {{timestamp}}
App Version: {{app_version}}

Message:
{{message}}

---
This feedback was submitted through the GraceAI app contact form.
```

### Option 2: Supabase Edge Function (Advanced)

1. **Deploy Edge Function:**
   ```bash
   supabase functions deploy send-feedback-email
   ```

2. **Set Environment Variables:**
   - `EMAIL_WEBHOOK_URL`: Your email service webhook
   - `EMAIL_API_KEY`: API key for email service

### Option 3: Simple Webhook Service

Use services like:
- **Zapier**: Create a Zap that triggers on Supabase database insert
- **Make.com**: Connect Supabase to email services
- **Pipedream**: Simple webhook processing

## Database Setup

Run the SQL script `create_feedback_table.sql` in your Supabase SQL Editor to create the feedback table.

## Testing

1. Submit feedback through the app
2. Check Supabase database for the feedback record
3. Verify email is received at darsh@graceai.music

## Current Implementation

The app currently:
1. ✅ Stores feedback in Supabase `feedback` table
2. ✅ Attempts to send email via Edge Function
3. ✅ Falls back gracefully if email sending fails
4. ✅ Provides user feedback on success/failure

## Next Steps

1. Choose an email service (EmailJS recommended)
2. Update the Edge Function with your email service credentials
3. Test the complete flow
4. Monitor feedback submissions in Supabase dashboard
