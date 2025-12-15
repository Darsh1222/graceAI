-- Update existing Supabase storage buckets and policies
-- This script safely updates existing buckets without conflicts

-- 1. Update existing buckets with correct settings
UPDATE storage.buckets 
SET 
    public = true,
    file_size_limit = 52428800,
    allowed_mime_types = ARRAY['audio/mpeg', 'audio/mp4', 'audio/wav', 'audio/m4a']
WHERE id = 'user-audio';

UPDATE storage.buckets 
SET 
    public = true,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['application/pdf', 'image/jpeg', 'image/png']
WHERE id = 'user-sheet-music';

UPDATE storage.buckets 
SET 
    public = true,
    file_size_limit = 1048576,
    allowed_mime_types = ARRAY['application/json', 'text/plain', 'audio/midi', 'image/png']
WHERE id = 'analysis-results';

-- 2. Drop existing policies if they exist (to recreate them properly)
DROP POLICY IF EXISTS "Users can upload their own audio files" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own audio files" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own sheet music" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own sheet music" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own analysis results" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own analysis results" ON storage.objects;

-- 3. Create new policies with proper user isolation
CREATE POLICY "Users can upload their own audio files" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'user-audio' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can view their own audio files" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'user-audio' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can upload their own sheet music" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'user-sheet-music' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can view their own sheet music" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'user-sheet-music' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can upload their own analysis results" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'analysis-results' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can view their own analysis results" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'analysis-results' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- 4. Enable RLS on storage.objects if not already enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 5. Grant necessary permissions to authenticated users
GRANT ALL ON storage.objects TO authenticated;
GRANT ALL ON storage.buckets TO authenticated;

-- 6. Verify the setup
SELECT 'Storage buckets updated successfully!' as status;
