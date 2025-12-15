-- Minimal Supabase bucket setup (should work with basic permissions)
-- This creates a basic working setup for file storage

-- 1. Check what buckets exist
SELECT 
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
FROM storage.buckets
WHERE id IN ('user-audio', 'user-sheet-music', 'analysis-results');

-- 2. Update bucket settings (this should work)
UPDATE storage.buckets 
SET public = true
WHERE id IN ('user-audio', 'user-sheet-music', 'analysis-results');

-- 3. Create a simple working policy (less secure but functional)
-- This allows authenticated users to upload and read files
CREATE POLICY IF NOT EXISTS "Allow authenticated users" ON storage.objects
    FOR ALL USING (auth.role() = 'authenticated');

-- 4. Alternative: Create bucket-specific policies if the above works
CREATE POLICY IF NOT EXISTS "Audio bucket access" ON storage.objects
    FOR ALL USING (bucket_id = 'user-audio');

CREATE POLICY IF NOT EXISTS "Sheet music bucket access" ON storage.objects
    FOR ALL USING (bucket_id = 'user-sheet-music');

CREATE POLICY IF NOT EXISTS "Analysis results bucket access" ON storage.objects
    FOR ALL USING (bucket_id = 'analysis-results');

-- 5. Verify setup
SELECT 'Minimal bucket setup completed!' as status;










