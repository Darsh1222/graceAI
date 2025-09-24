-- Fix Supabase Schema to Match iOS App Structure
-- Run this in your Supabase SQL Editor

-- 1. Update profiles table to match iOS UserProfile structure
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS skill_level TEXT DEFAULT 'beginner',
ADD COLUMN IF NOT EXISTS instruments TEXT[] DEFAULT '{}';

-- 2. Update sessions table to match iOS BackendSession structure  
ALTER TABLE sessions
ADD COLUMN IF NOT EXISTS date TEXT,
ADD COLUMN IF NOT EXISTS audio_file_name TEXT,
ADD COLUMN IF NOT EXISTS sheet_music_file_name TEXT,
ADD COLUMN IF NOT EXISTS piece_title TEXT,
ADD COLUMN IF NOT EXISTS duration DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS analysis_method TEXT,
ADD COLUMN IF NOT EXISTS total_user_notes INTEGER,
ADD COLUMN IF NOT EXISTS extra_notes TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS all_sheet_notes TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS all_audio_notes TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS overall_feedback TEXT,
ADD COLUMN IF NOT EXISTS tips TEXT[] DEFAULT '{}';

-- 3. Create a view to match iOS expectations for profiles
CREATE OR REPLACE VIEW user_profiles AS
SELECT 
    user_id::text as id,  -- Convert UUID to string and rename
    name,
    email,
    skill_level as "skillLevel",  -- Camel case for iOS
    instruments,
    created_at,
    updated_at
FROM profiles;

-- 4. Create a view to match iOS expectations for sessions
CREATE OR REPLACE VIEW user_sessions AS
SELECT 
    id::text as id,  -- Convert UUID to string
    user_id::text as "userId",  -- Camel case for iOS
    accuracy,
    correct_notes as "correctNotes",
    total_notes as "totalNotes",
    total_user_notes as "totalUserNotes",
    missed_notes as "missedNotes",
    extra_notes as "extraNotes",
    all_sheet_notes as "allSheetNotes", 
    all_audio_notes as "allAudioNotes",
    overall_feedback as "overallFeedback",
    tips,
    tempo_feedback as "tempoFeedback",
    timing_feedback as "timingFeedback",
    audio_url as "audioUrl",
    sheet_music_url as "sheetMusicUrl",
    audio_file_name as "audioFileName",
    sheet_music_file_name as "sheetMusicFileName",
    piece_title as "pieceTitle",
    duration,
    analysis_method as "analysisMethod",
    COALESCE(date, created_at::text) as date,
    created_at,
    updated_at
FROM sessions;

-- 5. Update RLS policies for the views
ALTER VIEW user_profiles OWNER TO postgres;
ALTER VIEW user_sessions OWNER TO postgres;

-- 6. Grant permissions on views
GRANT SELECT ON user_profiles TO anon, authenticated;
GRANT SELECT ON user_sessions TO anon, authenticated;

-- 7. Create RLS policies for views (if supported)
-- Note: Views inherit RLS from underlying tables

-- 8. Update the trigger function to handle new fields
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (user_id, name, email, skill_level, instruments)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', 'User'),
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'skillLevel', 'beginner'),
        COALESCE(
            ARRAY(SELECT jsonb_array_elements_text(NEW.raw_user_meta_data->'instruments')),
            '{}'::text[]
        )
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Fix any existing users without profiles
INSERT INTO profiles (user_id, name, email, skill_level, instruments)
SELECT 
    u.id,
    COALESCE(u.raw_user_meta_data->>'name', 'User'),
    u.email,
    'beginner',
    '{}'::text[]
FROM auth.users u
LEFT JOIN profiles p ON u.id = p.user_id
WHERE p.user_id IS NULL;

-- 10. Create indexes for better performance on new fields
CREATE INDEX IF NOT EXISTS idx_sessions_piece_title ON sessions(piece_title);
CREATE INDEX IF NOT EXISTS idx_sessions_analysis_method ON sessions(analysis_method);
CREATE INDEX IF NOT EXISTS idx_profiles_skill_level ON profiles(skill_level);

COMMENT ON TABLE profiles IS 'Updated to match iOS UserProfile structure';
COMMENT ON TABLE sessions IS 'Updated to match iOS BackendSession structure';
COMMENT ON VIEW user_profiles IS 'iOS-compatible view of profiles with camelCase fields';
COMMENT ON VIEW user_sessions IS 'iOS-compatible view of sessions with camelCase fields';
