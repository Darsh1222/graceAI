-- Update existing session to match iOS app expectations
UPDATE practice_sessions SET date = created_at, audio_file_name = 'testRecording.m4a', sheet_music_file_name = 'jinglebooomtestfr.pdf' WHERE id = 'cb172e0e-2504-426a-b7f0-c9105a9655c2';
-- Also update the sample data to real data from the analysis
UPDATE practice_sessions SET accuracy = 60.0, correct_notes = 6, total_notes = 10, missed_notes = 'F4,E4,C4,D4' WHERE id = 'cb172e0e-2504-426a-b7f0-c9105a9655c2';
