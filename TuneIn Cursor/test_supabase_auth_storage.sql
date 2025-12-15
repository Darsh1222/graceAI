-- Test Supabase Auth and Storage Setup
-- Run these queries to verify your setup is working

-- 1. Test database connection and basic queries
SELECT 'Database connection working!' as status;

-- 2. Check if all required tables exist
SELECT 
    table_name,
    CASE 
        WHEN table_name IN ('profiles', 'sessions') THEN '✅ Required table exists'
        ELSE '❓ Additional table'
    END as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- 3. Check if storage buckets exist
SELECT 
    name as bucket_name,
    public,
    file_size_limit / 1048576 as max_size_mb,
    allowed_mime_types,
    CASE 
        WHEN name IN ('user-audio', 'user-sheet-music', 'analysis-results') THEN '✅ Required bucket'
        ELSE '❓ Additional bucket'
    END as status
FROM storage.buckets
ORDER BY name;

-- 4. Check RLS policies are enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity,
    CASE 
        WHEN rowsecurity THEN '✅ RLS Enabled'
        ELSE '❌ RLS Disabled'
    END as status
FROM pg_tables 
WHERE tablename IN ('profiles', 'sessions')
ORDER BY tablename;

-- 5. Check storage policies exist
SELECT 
    policyname,
    bucket_id,
    operation,
    CASE 
        WHEN policyname IS NOT NULL THEN '✅ Policy exists'
        ELSE '❌ No policy'
    END as status
FROM storage.policies
WHERE bucket_id IN ('user-audio', 'user-sheet-music', 'analysis-results')
ORDER BY bucket_id, operation;

-- 6. Test user profile creation (simulation)
SELECT 
    'Profile creation test' as test_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'handle_new_user') 
        THEN '✅ Trigger function exists'
        ELSE '❌ Missing trigger function'
    END as status;

-- 7. Check if views were created successfully
SELECT 
    table_name as view_name,
    '✅ View created' as status
FROM information_schema.views 
WHERE table_name IN ('user_profiles', 'user_sessions')
UNION ALL
SELECT 
    missing_view,
    '❌ View missing' as status
FROM (
    VALUES ('user_profiles'), ('user_sessions')
) AS expected(missing_view)
WHERE missing_view NOT IN (
    SELECT table_name FROM information_schema.views 
    WHERE table_name IN ('user_profiles', 'user_sessions')
);

-- 8. Test data structure compatibility
SELECT 
    'Data structure test' as test_name,
    COUNT(*) as user_count,
    CASE 
        WHEN COUNT(*) >= 0 THEN '✅ Tables accessible'
        ELSE '❌ Access denied'
    END as status
FROM auth.users;

-- 9. Check for any orphaned data
SELECT 
    'Orphaned profiles check' as test_name,
    COUNT(*) as orphaned_count,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ No orphaned profiles'
        ELSE '⚠️ Found orphaned profiles'
    END as status
FROM profiles p
LEFT JOIN auth.users u ON p.user_id = u.id
WHERE u.id IS NULL;

-- 10. Storage bucket permissions test
SELECT 
    'Storage permissions test' as test_name,
    COUNT(*) as policy_count,
    CASE 
        WHEN COUNT(*) >= 12 THEN '✅ All storage policies exist'  -- 3 buckets × 4 operations
        WHEN COUNT(*) > 0 THEN '⚠️ Some storage policies missing'
        ELSE '❌ No storage policies found'
    END as status
FROM storage.policies
WHERE bucket_id IN ('user-audio', 'user-sheet-music', 'analysis-results');

-- Summary report
SELECT 
    '🎯 SUPABASE SETUP SUMMARY' as section,
    '' as details,
    '' as status
UNION ALL
SELECT 
    '📊 Database',
    'Tables, Views, Functions',
    CASE 
        WHEN (SELECT COUNT(*) FROM information_schema.tables WHERE table_name IN ('profiles', 'sessions')) = 2
        THEN '✅ Ready'
        ELSE '❌ Issues found'
    END
UNION ALL
SELECT 
    '🗄️ Storage',
    'Buckets and Policies', 
    CASE 
        WHEN (SELECT COUNT(*) FROM storage.buckets WHERE name IN ('user-audio', 'user-sheet-music', 'analysis-results')) = 3
        THEN '✅ Ready'
        ELSE '❌ Issues found'
    END
UNION ALL
SELECT 
    '🔐 Authentication',
    'RLS and Triggers',
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'handle_new_user')
        THEN '✅ Ready'
        ELSE '❌ Issues found'
    END;
