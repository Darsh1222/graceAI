-- Fix Storage Bucket Access for Backend
-- This allows the AWS backend to download files that users upload
-- Run this in your Supabase SQL Editor

-- First, drop the restrictive SELECT policies
DROP POLICY IF EXISTS "Users can view their own audio files" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own sheet music" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own analysis results" ON storage.objects;

-- Create new policies that allow:
-- 1. Users can only UPLOAD their own files (security maintained)
-- 2. Anyone can READ files (needed for backend to download)

-- Audio files: Users upload their own, anyone can read
CREATE POLICY "Users can upload their own audio files" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'user-audio' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Anyone can view audio files" ON storage.objects
    FOR SELECT USING (bucket_id = 'user-audio');

-- Sheet music: Users upload their own, anyone can read
CREATE POLICY "Users can upload their own sheet music" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'user-sheet-music' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Anyone can view sheet music" ON storage.objects
    FOR SELECT USING (bucket_id = 'user-sheet-music');

-- Analysis results: Users upload their own, anyone can read
CREATE POLICY "Users can upload their own analysis results" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'analysis-results' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Anyone can view analysis results" ON storage.objects
    FOR SELECT USING (bucket_id = 'analysis-results');

-- Verify the changes
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'objects'
ORDER BY policyname;


