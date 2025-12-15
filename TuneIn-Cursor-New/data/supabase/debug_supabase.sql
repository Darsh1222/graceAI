-- Debug Supabase User Profile Creation
-- Run these queries in your Supabase SQL Editor to debug the issue

-- 1. Check if the trigger function exists
SELECT 
    routine_name, 
    routine_type 
FROM information_schema.routines 
WHERE routine_name = 'handle_new_user';

-- 2. Check if the trigger exists
SELECT 
    trigger_name, 
    event_manipulation, 
    event_object_table, 
    action_statement 
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- 3. Check existing users in auth.users
SELECT 
    id, 
    email, 
    raw_user_meta_data,
    created_at 
FROM auth.users 
ORDER BY created_at DESC 
LIMIT 5;

-- 4. Check existing profiles
SELECT 
    user_id, 
    name, 
    email, 
    created_at 
FROM profiles 
ORDER BY created_at DESC 
LIMIT 5;

-- 5. Check if there are users without profiles
SELECT 
    u.id, 
    u.email, 
    u.raw_user_meta_data,
    p.user_id as profile_exists
FROM auth.users u
LEFT JOIN profiles p ON u.id = p.user_id
WHERE p.user_id IS NULL
ORDER BY u.created_at DESC;

-- 6. Manually create a profile for existing users (if needed)
-- Replace 'USER_ID_HERE' with an actual user ID from step 5
-- INSERT INTO profiles (user_id, name, email)
-- VALUES (
--     'USER_ID_HERE',
--     COALESCE((SELECT raw_user_meta_data->>'name' FROM auth.users WHERE id = 'USER_ID_HERE'), 'User'),
--     (SELECT email FROM auth.users WHERE id = 'USER_ID_HERE')
-- );

-- 7. Test the trigger function manually
-- Replace 'TEST_USER_ID' with a real user ID
-- SELECT handle_new_user();

-- 8. Check RLS policies
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd, 
    qual 
FROM pg_policies 
WHERE tablename IN ('profiles', 'sessions'); 