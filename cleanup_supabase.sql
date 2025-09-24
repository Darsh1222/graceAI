-- Clean up old test data and users from Supabase
-- Run this in your Supabase SQL editor

-- First, let's see what data we have
SELECT 'profiles' as table_name, count(*) as count FROM profiles
UNION ALL
SELECT 'sessions' as table_name, count(*) as count FROM sessions
UNION ALL
SELECT 'auth.users' as table_name, count(*) as count FROM auth.users;

-- Delete old test sessions (older than 1 day)
DELETE FROM sessions 
WHERE created_at < NOW() - INTERVAL '1 day';

-- Delete old test profiles that don't have corresponding auth users
DELETE FROM profiles 
WHERE user_id NOT IN (
    SELECT id FROM auth.users
);

-- Delete old auth users that are test users (you can modify this condition)
DELETE FROM auth.users 
WHERE email LIKE '%test%' 
   OR email LIKE '%@graceai.com'
   OR created_at < NOW() - INTERVAL '7 days';

-- Show remaining data
SELECT 'After cleanup - profiles' as table_name, count(*) as count FROM profiles
UNION ALL
SELECT 'After cleanup - sessions' as table_name, count(*) as count FROM sessions
UNION ALL
SELECT 'After cleanup - auth.users' as table_name, count(*) as count FROM auth.users;
