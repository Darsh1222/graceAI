-- Check existing Supabase storage buckets and policies
-- Run this in your Supabase SQL Editor to see what's already configured

-- 1. Check existing storage buckets
SELECT 
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types,
    created_at
FROM storage.buckets
WHERE id IN ('user-audio', 'user-sheet-music', 'analysis-results')
ORDER BY id;

-- 2. Check existing storage policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage'
ORDER BY policyname;

-- 3. Check if RLS is enabled on storage.objects
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE schemaname = 'storage' 
AND tablename = 'objects';

-- 4. Check bucket permissions for authenticated users
SELECT 
    grantee,
    privilege_type,
    is_grantable
FROM information_schema.role_table_grants 
WHERE table_schema = 'storage' 
AND table_name = 'objects';
