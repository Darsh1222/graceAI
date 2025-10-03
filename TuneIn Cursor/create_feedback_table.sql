-- Create feedback table for storing user feedback
-- Run this in your Supabase SQL Editor

-- Create feedback table
CREATE TABLE IF NOT EXISTS feedback (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    message TEXT NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    app_version TEXT DEFAULT 'GraceAI eos1.1',
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'responded')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_feedback_timestamp ON feedback(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_feedback_status ON feedback(status);

-- Enable Row Level Security (RLS)
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

-- Create policy to allow anyone to insert feedback (for contact form)
CREATE POLICY "Anyone can submit feedback" ON feedback
    FOR INSERT WITH CHECK (true);

-- Create policy to allow authenticated users to view their own feedback
CREATE POLICY "Users can view feedback" ON feedback
    FOR SELECT USING (auth.role() = 'authenticated');

-- Create a trigger to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_feedback_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_feedback_updated_at
    BEFORE UPDATE ON feedback
    FOR EACH ROW
    EXECUTE FUNCTION update_feedback_updated_at();

-- Optional: Create a view for easy feedback management
CREATE OR REPLACE VIEW feedback_summary AS
SELECT 
    id,
    name,
    email,
    LEFT(message, 100) || '...' as message_preview,
    timestamp,
    app_version,
    status,
    created_at,
    updated_at
FROM feedback
ORDER BY timestamp DESC;
