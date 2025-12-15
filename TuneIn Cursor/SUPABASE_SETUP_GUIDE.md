# 🚀 Supabase Setup Guide for TuneIn Cursor

## 📋 Prerequisites
- Supabase account (free tier works great!)
- Your project URL: `https://cjqmnznipjwdxgqdegov.supabase.co`
- Your anon key: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNqcW1uem5pcGp3ZHhncWRlZ292Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ1MDQ5NzEsImV4cCI6MjA3MDA4MDk3MX0.2de1-z-UxDP9EkBq4DfGSponnioTLtOy1Vy4y9lsZWg`

## 🗄️ Database Setup

### 1. Create Database Schema
1. Go to your Supabase dashboard
2. Navigate to **SQL Editor**
3. Copy and paste the contents of `supabase_schema.sql`
4. Click **Run** to execute the schema

### 2. Verify Tables Created
Check that these tables exist in **Table Editor**:
- ✅ `profiles` - User profile information
- ✅ `sessions` - Practice session data
- ✅ `auth.users` - Supabase auth users (auto-created)

## 📁 Storage Buckets Setup

### 1. Create Storage Buckets
1. Go to **Storage** in your Supabase dashboard
2. Create these buckets:
   - `user-audio` - For audio recordings (.m4a files)
   - `user-sheet-music` - For sheet music PDFs
   - `analysis-results` - For analysis data

### 2. Set Bucket Permissions
For each bucket, set these policies:

```sql
-- Allow authenticated users to upload files
CREATE POLICY "Users can upload files" ON storage.objects
FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Allow users to view their own files
CREATE POLICY "Users can view own files" ON storage.objects
FOR SELECT USING (auth.uid()::text = (storage.foldername(name))[1]);

-- Allow users to update their own files
CREATE POLICY "Users can update own files" ON storage.objects
FOR UPDATE USING (auth.uid()::text = (storage.foldername(name))[1]);

-- Allow users to delete their own files
CREATE POLICY "Users can delete own files" ON storage.objects
FOR DELETE USING (auth.uid()::text = (storage.foldername(name))[1]);
```

## 🔐 Authentication Setup

### 1. Enable Email Auth
1. Go to **Authentication > Settings**
2. Enable **Email** provider
3. Configure email templates (optional)

### 2. Set Site URL
1. Go to **Authentication > Settings**
2. Set **Site URL** to your app's URL
3. Add redirect URLs if needed

## 📱 iOS App Integration

### ✅ Already Implemented
- ✅ Supabase configuration with your credentials
- ✅ Authentication service (sign up/sign in)
- ✅ User profile management
- ✅ Session data storage and retrieval
- ✅ File upload to Supabase Storage
- ✅ Row Level Security (RLS) policies

### 🔧 What's Working
1. **User Registration** - Creates account in Supabase Auth
2. **User Login** - Authenticates with Supabase
3. **Profile Management** - Stores user data in profiles table
4. **Session Storage** - Saves practice sessions to database
5. **Data Retrieval** - Fetches user sessions for history
6. **File Management** - Uploads files to Supabase Storage

## 🧪 Testing the Integration

### 1. Test User Registration
1. Run the app
2. Go to Login screen
3. Tap "Create Account"
4. Enter name, email, and password
5. Verify user is created in Supabase Auth

### 2. Test Session Storage
1. Complete a practice session
2. Check the `sessions` table in Supabase
3. Verify session data is stored correctly

### 3. Test Data Retrieval
1. Go to History tab
2. Verify sessions load from Supabase
3. Check that data is filtered by user

## 🔧 Troubleshooting

### Common Issues

#### 1. Authentication Errors
```swift
// Check your credentials in SupabaseConfig
static let url = "https://cjqmnznipjwdxgqdegov.supabase.co"
static let anonKey = "your-anon-key"
```

#### 2. Database Connection Issues
- Verify RLS policies are enabled
- Check table permissions
- Ensure schema was created correctly

#### 3. File Upload Issues
- Verify storage buckets exist
- Check bucket permissions
- Ensure file size limits are appropriate

### Debug Commands
```swift
// Add to your code for debugging
print("🔍 Supabase URL: \(SupabaseConfig.url)")
print("🔍 User ID: \(userProfile?.id ?? "nil")")
print("🔍 Session count: \(sessions.count)")
```

## 📊 Monitoring

### 1. Supabase Dashboard
- **Database** - Monitor table growth and queries
- **Storage** - Track file uploads and storage usage
- **Auth** - View user registrations and logins
- **Logs** - Check for errors and performance issues

### 2. Key Metrics to Watch
- User registration rate
- Session storage frequency
- File upload success rate
- API response times

## 🚀 Production Considerations

### 1. Security
- ✅ RLS policies protect user data
- ✅ Authentication required for all operations
- ✅ File access restricted to owners

### 2. Performance
- Indexes on frequently queried columns
- Efficient session retrieval with ordering
- Optimized file storage structure

### 3. Scalability
- Supabase handles scaling automatically
- Database can handle thousands of users
- Storage scales with usage

## 📞 Support

If you encounter issues:
1. Check Supabase logs in dashboard
2. Verify network connectivity
3. Test with simple API calls
4. Review RLS policies

Your Supabase integration is now complete and ready for production! 🎉 