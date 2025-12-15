-- Create Storage Buckets for TuneIn Cursor
-- Run this in your Supabase SQL Editor

-- Create storage buckets for different file types
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('user-audio', 'user-audio', true, 52428800, ARRAY['audio/mpeg', 'audio/mp4', 'audio/wav', 'audio/m4a']),
    ('user-sheet-music', 'user-sheet-music', true, 10485760, ARRAY['application/pdf', 'image/jpeg', 'image/png']),
    ('analysis-results', 'analysis-results', true, 1048576, ARRAY['application/json', 'text/plain']);

-- Create RLS policies for storage buckets
CREATE POLICY "Users can upload their own audio files" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'user-audio' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view their own audio files" ON storage.objects
    FOR SELECT USING (bucket_id = 'user-audio' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can upload their own sheet music" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'user-sheet-music' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view their own sheet music" ON storage.objects
    FOR SELECT USING (bucket_id = 'user-sheet-music' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can upload their own analysis results" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'analysis-results' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view their own analysis results" ON storage.objects
    FOR SELECT USING (bucket_id = 'analysis-results' AND auth.uid()::text = (storage.foldername(name))[1]); 