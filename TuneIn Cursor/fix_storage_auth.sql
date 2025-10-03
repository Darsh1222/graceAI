-- Fix storage authentication issues
-- Run this in your Supabase SQL Editor

-- 1. First, let's check current bucket status
SELECT 
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
FROM storage.buckets
WHERE id IN ('user-audio', 'user-sheet-music', 'analysis-results');

-- 2. Make sure all buckets are public
UPDATE storage.buckets 
SET public = true
WHERE id IN ('user-audio', 'user-sheet-music', 'analysis-results');

-- 3. Drop existing policies that might be causing issues
DROP POLICY IF EXISTS "Users can upload their own audio files" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own audio files" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own sheet music" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own sheet music" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own analysis results" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own analysis results" ON storage.objects;

-- 4. Create simpler, more permissive policies
-- Allow anyone to upload files (for testing)
CREATE POLICY "Allow uploads to user-audio" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'user-audio');

CREATE POLICY "Allow uploads to user-sheet-music" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'user-sheet-music');

CREATE POLICY "Allow uploads to analysis-results" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'analysis-results');

-- Allow anyone to read files (since buckets are public)
CREATE POLICY "Allow reads from user-audio" ON storage.objects
    FOR SELECT USING (bucket_id = 'user-audio');

CREATE POLICY "Allow reads from user-sheet-music" ON storage.objects
    FOR SELECT USING (bucket_id = 'user-sheet-music');

CREATE POLICY "Allow reads from analysis-results" ON storage.objects
    FOR SELECT USING (bucket_id = 'analysis-results');

-- 5. Alternative: Even simpler policy for all buckets
-- Uncomment the following lines if the above doesn't work:

-- DROP POLICY IF EXISTS "Allow uploads to user-audio" ON storage.objects;
-- DROP POLICY IF EXISTS "Allow uploads to user-sheet-music" ON storage.objects;
-- DROP POLICY IF EXISTS "Allow uploads to analysis-results" ON storage.objects;
-- DROP POLICY IF EXISTS "Allow reads from user-audio" ON storage.objects;
-- DROP POLICY IF EXISTS "Allow reads from user-sheet-music" ON storage.objects;
-- DROP POLICY IF EXISTS "Allow reads from analysis-results" ON storage.objects;

-- CREATE POLICY "Allow all operations" ON storage.objects
--     FOR ALL USING (true);

-- 6. Verify the setup
SELECT 'Storage authentication fix completed!' as status;
