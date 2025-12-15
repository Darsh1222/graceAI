-- Add all_audio_notes and all_sheet_notes columns to sessions table
-- These will store the actual detected notes as text arrays

ALTER TABLE sessions 
ADD COLUMN IF NOT EXISTS all_audio_notes TEXT[],
ADD COLUMN IF NOT EXISTS all_sheet_notes TEXT[];

-- Update existing sessions to have empty arrays (they won't have the original note data)
UPDATE sessions 
SET all_audio_notes = '{}'::TEXT[], 
    all_sheet_notes = '{}'::TEXT[]
WHERE all_audio_notes IS NULL OR all_sheet_notes IS NULL;

-- Add comments for documentation
COMMENT ON COLUMN sessions.all_audio_notes IS 'Array of all notes detected in the audio file';
COMMENT ON COLUMN sessions.all_sheet_notes IS 'Array of all notes detected in the sheet music file';
