# AWS + Supabase Deployment Guide

## 🚀 Production Deployment Checklist

### ✅ What's Already Fixed
- [x] Environment-based configuration
- [x] File validation and security
- [x] Proper error handling and logging
- [x] Docker containerization
- [x] Health checks
- [x] No more hardcoded IP addresses

### 🔧 AWS Deployment Steps

#### 1. **AWS ECS (Elastic Container Service) Setup**
```bash
# Build and push Docker image
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin your-account.dkr.ecr.us-east-1.amazonaws.com
docker build -t graceai-backend .
docker tag graceai-backend:latest your-account.dkr.ecr.us-east-1.amazonaws.com/graceai-backend:latest
docker push your-account.dkr.ecr.us-east-1.amazonaws.com/graceai-backend:latest
```

#### 2. **Environment Variables in AWS**
Set these in ECS Task Definition:
```bash
ENVIRONMENT=production
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your_supabase_anon_key
PORT=8000
HOST=0.0.0.0
```

#### 3. **Load Balancer & HTTPS**
- Use AWS Application Load Balancer
- Configure SSL certificate with AWS Certificate Manager
- Set up domain routing

### 🔐 Supabase Integration

#### 1. **Database Schema**
```sql
-- Users table (handled by Supabase Auth)
-- profiles table will be auto-created

-- Practice sessions table
CREATE TABLE practice_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
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

-- Enable RLS (Row Level Security)
ALTER TABLE practice_sessions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own sessions
CREATE POLICY "Users can view own sessions" ON practice_sessions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sessions" ON practice_sessions
    FOR INSERT WITH CHECK (auth.uid() = user_id);
```

#### 2. **Storage Buckets**
```sql
-- Create storage buckets
INSERT INTO storage.buckets (id, name, public) VALUES 
('audio-files', 'audio-files', false),
('sheet-music', 'sheet-music', false);

-- Storage policies
CREATE POLICY "Users can upload own files" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id IN ('audio-files', 'sheet-music') AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view own files" ON storage.objects
    FOR SELECT USING (bucket_id IN ('audio-files', 'sheet-music') AND auth.uid()::text = (storage.foldername(name))[1]);
```

### 📱 iOS App Updates Needed

#### 1. **Update Backend URL**
Replace the placeholder in `ContentView.swift`:
```swift
// Production - use your AWS domain
return "https://your-api-domain.com" // Replace with actual AWS domain
```

#### 2. **Add Supabase Integration**
```swift
import Supabase

class SupabaseService {
    static let shared = SupabaseService()
    private let client: SupabaseClient
    
    init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "YOUR_SUPABASE_URL")!,
            supabaseKey: "YOUR_SUPABASE_ANON_KEY"
        )
    }
    
    func uploadFile(_ fileURL: URL, bucket: String, path: String) async throws -> String {
        let file = try await client.storage
            .from(bucket)
            .upload(
                path: path,
                file: fileURL,
                options: FileOptions(cacheControl: "3600")
            )
        
        return try await client.storage
            .from(bucket)
            .getPublicURL(path: path)
            .absoluteString
    }
}
```

### 🔄 Migration Steps

#### 1. **Deploy Backend to AWS**
1. Build and push Docker image to ECR
2. Create ECS cluster and service
3. Configure load balancer and domain
4. Set environment variables

#### 2. **Set Up Supabase**
1. Create new Supabase project
2. Run database schema migrations
3. Configure storage buckets and policies
4. Get API keys

#### 3. **Update iOS App**
1. Update backend URL to AWS domain
2. Integrate Supabase for auth and storage
3. Test file uploads and analysis

#### 4. **Testing**
1. Test authentication flow
2. Test file uploads to Supabase
3. Test analysis pipeline
4. Test session retrieval

### 🛡️ Security Considerations

#### ✅ Implemented
- [x] File type validation
- [x] File size limits
- [x] Environment-based configuration
- [x] Proper error handling
- [x] Non-root Docker user

#### 🔄 Still Needed
- [ ] Rate limiting
- [ ] API authentication (JWT tokens)
- [ ] Input sanitization
- [ ] CORS configuration
- [ ] Request logging and monitoring

### 📊 Monitoring & Logging

#### AWS CloudWatch
```bash
# Set up CloudWatch logging
aws logs create-log-group --log-group-name /ecs/graceai-backend
aws logs put-retention-policy --log-group-name /ecs/graceai-backend --retention-in-days 30
```

#### Health Checks
- Application health: `/health`
- Database connectivity
- File storage connectivity
- Analysis pipeline status

### 🚀 Go-Live Checklist

- [ ] AWS ECS service deployed and healthy
- [ ] Supabase project configured
- [ ] iOS app updated with new backend URL
- [ ] SSL certificate configured
- [ ] Domain DNS configured
- [ ] File uploads working
- [ ] Analysis pipeline working
- [ ] User authentication working
- [ ] Session storage working
- [ ] Monitoring and alerts configured

### 💰 Cost Estimation

#### AWS Monthly Costs (estimated)
- ECS Fargate: ~$30-50/month
- Application Load Balancer: ~$20/month
- CloudWatch Logs: ~$5-10/month
- Data transfer: ~$5-15/month

#### Supabase Monthly Costs
- Pro plan: $25/month (includes 100GB storage, 2GB bandwidth)

**Total estimated cost: ~$85-125/month**

### 🆘 Troubleshooting

#### Common Issues
1. **CORS errors**: Check ALLOWED_ORIGINS in environment
2. **File upload failures**: Check Supabase storage policies
3. **Analysis pipeline errors**: Check ECS task logs
4. **Authentication issues**: Verify Supabase JWT configuration

#### Debug Commands
```bash
# Check ECS service status
aws ecs describe-services --cluster graceai-cluster --services graceai-backend

# View CloudWatch logs
aws logs tail /ecs/graceai-backend --follow

# Test health endpoint
curl https://your-api-domain.com/health
``` 