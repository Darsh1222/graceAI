-- Fix profiles table schema to match UserProfile model
-- Run this in your Supabase SQL Editor

-- Add missing columns to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS skill_level TEXT DEFAULT 'Beginner',
ADD COLUMN IF NOT EXISTS instruments TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS total_sessions INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS average_accuracy REAL DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS best_accuracy REAL DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS total_practice_time REAL DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS current_streak INTEGER DEFAULT 0;

-- Update existing profiles with default values
UPDATE profiles 
SET 
    skill_level = 'Beginner',
    instruments = '{}',
    total_sessions = 0,
    average_accuracy = 0.0,
    best_accuracy = 0.0,
    total_practice_time = 0.0,
    current_streak = 0
WHERE skill_level IS NULL;

-- Verify the schema
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'profiles' 
ORDER BY ordinal_position;
