-- Fix the array syntax for missed_notes
UPDATE practice_sessions SET date = created_at, audio_file_name = 'testRecording.m4a', sheet_music_file_name = 'jinglebooomtestfr.pdf' WHERE id = 'cb172e0e-2504-426a-b7f0-c9105a9655c2';
UPDATE practice_sessions SET accuracy = 60.0, correct_notes = 6, total_notes = 10, missed_notes = ARRAY['F4','E4','C4','D4'] WHERE id = 'cb172e0e-2504-426a-b7f0-c9105a9655c2';
