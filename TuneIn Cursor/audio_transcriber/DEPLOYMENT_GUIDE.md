# TuneIn Deployment Guide

## Recommended Flow: Supabase + Railway

### **Architecture Overview**
```
iOS App → Supabase (Data) → Railway Flask Server (Processing) → Supabase (Results)
```

## Phase 1: Set Up Supabase

### **Step 1: Create Supabase Project**
1. Go to [supabase.com](https://supabase.com)
2. Sign up and create a new project
3. Note your project URL and API key

### **Step 2: Set Up Database Tables**
Run these SQL commands in your Supabase SQL editor:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- User profiles table (extends Supabase Auth)
CREATE TABLE user_profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  name TEXT,
  email TEXT,
  join_date TIMESTAMP DEFAULT NOW(),
  total_sessions INTEGER DEFAULT 0,
  average_accuracy REAL DEFAULT 0.0,
  total_practice_time REAL DEFAULT 0.0,
  current_streak INTEGER DEFAULT 0,
  best_accuracy REAL DEFAULT 0.0,
  favorite_pieces TEXT[]
);

-- Practice sessions table
CREATE TABLE practice_sessions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMP DEFAULT NOW(),
  audio_file_url TEXT,
  sheet_music_url TEXT,
  piece_title TEXT,
  duration REAL,
  accuracy REAL,
  correct_notes INTEGER,
  total_notes INTEGER,
  missed_notes TEXT[],
  tempo_feedback TEXT,
  timing_feedback TEXT
);

-- Enable Row Level Security
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE practice_sessions ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view own profile" ON user_profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON user_profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can view own sessions" ON practice_sessions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sessions" ON practice_sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id);
```

### **Step 3: Set Up File Storage**
1. Go to Storage in your Supabase dashboard
2. Create a new bucket called `files`
3. Set it to public (for file access)
4. Configure CORS if needed

## Phase 2: Deploy Flask Server to Railway

### **Step 1: Install Railway CLI**
```bash
npm install -g @railway/cli
```

### **Step 2: Prepare Your Project**
```bash
# Navigate to your project directory
cd "TuneIn Cursor/audio_transcriber"

# Create .env file for local development
echo "SUPABASE_URL=your-supabase-url" > .env
echo "SUPABASE_KEY=your-supabase-key" >> .env
```

### **Step 3: Create Railway Configuration**
Create `railway.json`:
```json
{
  "build": {
    "builder": "nixpacks"
  },
  "deploy": {
    "startCommand": "gunicorn supabase_integration:app --bind 0.0.0.0:$PORT",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

### **Step 4: Deploy to Railway**
```bash
# Login to Railway
railway login

# Initialize project
railway init

# Add environment variables
railway variables set SUPABASE_URL=your-supabase-url
railway variables set SUPABASE_KEY=your-supabase-key

# Deploy
railway up
```

### **Step 5: Get Your Railway URL**
```bash
railway status
# Note the URL (e.g., https://tunein-backend.railway.app)
```

## Phase 3: Update iOS App

### **Step 1: Install Supabase Swift Client**
Add to your `Package.swift` or use Swift Package Manager:
```swift
dependencies: [
    .package(url: "https://github.com/supabase-community/supabase-swift.git", from: "0.3.0")
]
```

### **Step 2: Create Supabase Client**
```swift
import Supabase

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    private let client: SupabaseClient
    
    init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "YOUR_SUPABASE_URL")!,
            supabaseKey: "YOUR_SUPABASE_KEY"
        )
    }
    
    // Authentication
    func signUp(email: String, password: String) async throws -> User {
        let response = try await client.auth.signUp(
            email: email,
            password: password
        )
        return response.user!
    }
    
    func signIn(email: String, password: String) async throws -> User {
        let response = try await client.auth.signIn(
            email: email,
            password: password
        )
        return response.user!
    }
    
    // Practice sessions
    func savePracticeSession(_ session: PracticeSession) async throws {
        try await client.database
            .from("practice_sessions")
            .insert(session.toDictionary())
            .execute()
    }
    
    func getPracticeSessions() async throws -> [PracticeSession] {
        let response = try await client.database
            .from("practice_sessions")
            .select()
            .order("created_at", ascending: false)
            .execute()
        
        return response.data.compactMap { PracticeSession(from: $0) }
    }
}
```

### **Step 3: Update API Calls**
Replace your current Flask API calls with Supabase calls:

```swift
// Instead of calling your Flask server directly
// Use Supabase for data operations

// Save session
try await SupabaseManager.shared.savePracticeSession(session)

// Get sessions
let sessions = try await SupabaseManager.shared.getPracticeSessions()

// For audio processing, still call your Railway server
let analysisResult = try await uploadToRailwayServer(audioFile, sheetMusicFile)
```

## Phase 4: Test the Integration

### **Step 1: Test Supabase Connection**
```bash
# Test with curl
curl -X POST "https://your-railway-url.railway.app/health"
```

### **Step 2: Test File Upload**
```bash
# Test file upload to Supabase
curl -X POST "https://your-railway-url.railway.app/analyze" \
  -F "audio_file=@test.m4a" \
  -F "sheet_music=@test.pdf" \
  -F "user_id=test-user-id"
```

### **Step 3: Test iOS App**
1. Update your iOS app with Supabase integration
2. Test user registration/login
3. Test practice session upload
4. Test session history retrieval

## Phase 5: Monitor and Optimize

### **Step 1: Set Up Monitoring**
- Railway provides basic monitoring
- Set up alerts for errors
- Monitor API response times

### **Step 2: Optimize Performance**
- Add caching for frequently accessed data
- Optimize file upload sizes
- Monitor database query performance

### **Step 3: Scale as Needed**
- Railway auto-scales based on usage
- Supabase scales automatically
- Monitor costs and usage

## Cost Breakdown

### **Railway:**
- **Free Tier**: $5 credit/month
- **Pro**: $20/month for unlimited usage
- **Your App**: Likely $5-15/month

### **Supabase:**
- **Free Tier**: 50,000 users, 500MB database, 1GB storage
- **Pro**: $25/month for 100,000 users, 8GB database, 100GB storage
- **Your App**: Free tier should be sufficient initially

### **Total Estimated Cost: $5-40/month**

## Troubleshooting

### **Common Issues:**

1. **Supabase Connection Errors**
   - Check API keys
   - Verify project URL
   - Check CORS settings

2. **Railway Deployment Failures**
   - Check requirements.txt
   - Verify environment variables
   - Check logs with `railway logs`

3. **File Upload Issues**
   - Check Supabase storage bucket permissions
   - Verify file size limits
   - Check CORS configuration

### **Debug Commands:**
```bash
# Check Railway logs
railway logs

# Check Railway status
railway status

# Test Supabase connection
curl -X GET "https://your-project.supabase.co/rest/v1/practice_sessions" \
  -H "apikey: YOUR_SUPABASE_KEY"
```

## Next Steps

### **Immediate:**
1. Deploy to Railway
2. Test basic functionality
3. Update iOS app

### **Short-term:**
1. Add real-time updates
2. Implement user authentication
3. Add error handling

### **Long-term:**
1. Add analytics
2. Implement advanced features
3. Consider migration to AWS if needed

## Migration from Current Setup

### **Step 1: Export Current Data**
```python
# Export from SQLite
import sqlite3
import json

conn = sqlite3.connect('tunein_data.db')
cursor = conn.cursor()

cursor.execute('SELECT * FROM users')
users = cursor.fetchall()

cursor.execute('SELECT * FROM practice_sessions')
sessions = cursor.fetchall()

with open('export.json', 'w') as f:
    json.dump({'users': users, 'sessions': sessions}, f)
```

### **Step 2: Import to Supabase**
```python
# Import to Supabase
import json
from supabase import create_client

with open('export.json', 'r') as f:
    data = json.load(f)

# Import users and sessions
for user in data['users']:
    # Import user data
    pass

for session in data['sessions']:
    # Import session data
    pass
```

### **Step 3: Update iOS App**
1. Replace local storage with Supabase
2. Update API endpoints
3. Test thoroughly

This setup gives you the best of both worlds: easy data management with Supabase and powerful audio processing with your Flask server on Railway. 