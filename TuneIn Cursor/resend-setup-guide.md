# 📧 Resend Email Setup Guide

## 🚀 Quick Setup (5 minutes)

### Step 1: Create Resend Account
1. **Go to**: https://resend.com/
2. **Sign up** for free account
3. **Verify your email**

### Step 2: Get API Key
1. **Go to**: https://resend.com/api-keys
2. **Click "Create API Key"**
3. **Name it**: `GraceAI Feedback`
4. **Copy the API key** (starts with `re_...`)

### Step 3: Add Domain (Optional but Recommended)
1. **Go to**: https://resend.com/domains
2. **Add domain**: `graceai.music`
3. **Follow DNS setup** (add TXT record)
4. **Verify domain**

### Step 4: Deploy Edge Function
Run this command in your project directory:
```bash
supabase functions deploy send-feedback-email
```

### Step 5: Set Environment Variable
In your Supabase dashboard:
1. **Go to**: Settings → Edge Functions
2. **Find**: `send-feedback-email`
3. **Add environment variable**:
   - **Key**: `RESEND_API_KEY`
   - **Value**: `re_xxxxxxxxxx` (your API key from Step 2)

## 🎯 What This Does

✅ **Beautiful HTML emails** sent to `darsh@graceai.music`  
✅ **Automatic fallback** to database storage if email fails  
✅ **Rich formatting** with user details and message  
✅ **Error handling** with detailed logging  

## 📋 Email Template Preview

**Subject**: `New Feedback from GraceAI App - [User Name]`

**Content**:
- User's name and email
- Timestamp and app version
- Full message in a nicely formatted box
- Professional styling with GraceAI branding

## 🧪 Testing

1. **Submit feedback** through your app
2. **Check email** at `darsh@graceai.music`
3. **Check Supabase logs** for any errors

## 💡 Benefits of Resend

- **Free tier**: 3,000 emails/month
- **High deliverability**: Professional email service
- **Beautiful templates**: Rich HTML formatting
- **Developer friendly**: Simple API
- **Reliable**: Used by top companies

## 🔧 Troubleshooting

**If emails don't arrive:**
1. Check Supabase Edge Function logs
2. Verify `RESEND_API_KEY` is set correctly
3. Check spam folder
4. Verify domain is configured (if using custom domain)

**Fallback system:**
- If email fails, feedback is stored in `feedback_emails` table
- You can manually process failed emails from Supabase dashboard
