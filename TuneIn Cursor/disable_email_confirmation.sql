-- Disable Email Confirmation for Development
-- Run this in your Supabase SQL Editor

-- Update the auth settings to disable email confirmation
UPDATE auth.config 
SET confirm_email_change = false,
    enable_signup = true,
    enable_confirmations = false;

-- Or you can also do this through the Supabase Dashboard:
-- 1. Go to Authentication → Settings
-- 2. Turn off "Enable email confirmations"
-- 3. Save the changes 