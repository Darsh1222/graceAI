# 🚀 Complete AWS Deployment Guide for TuneIn Cursor

## 📋 Overview
This guide will walk you through deploying the TuneIn Cursor backend to AWS using ECS Fargate, Application Load Balancer, and CloudFormation.

## ✅ What We've Fixed

### 1. **Supabase Bucket Issues** ✅
- Updated `supabase_integration.py` to use correct bucket names:
  - `user-audio` for audio files
  - `user-sheet-music` for sheet music
  - `analysis-results` for analysis outputs
- Added analysis results upload functionality
- Fixed file download paths

### 2. **iOS App Authentication** ✅
- Added password confirmation field for signup
- Added password visibility toggle (eye icon) for both password fields
- Enhanced form validation
- Improved UX with form clearing when switching modes

### 3. **AWS Infrastructure** ✅
- Complete CloudFormation template
- Automated deployment script
- Environment configuration
- Security groups and networking

## 🛠️ Prerequisites

### Required Software
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

# Install Docker Desktop
# Download from: https://www.docker.com/products/docker-desktop

# Install jq (JSON processor)
brew install jq  # macOS
# or
sudo apt-get install jq  # Ubuntu/Debian
```

### AWS Account Setup
```bash
# Configure AWS credentials
aws configure

# Set your:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format (json)
```

## 🚀 Step-by-Step Deployment

### Step 1: Prepare Supabase
```sql
-- Run this in your Supabase SQL Editor
-- Create storage buckets for different file types
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('user-audio', 'user-audio', true, 52428800, ARRAY['audio/mpeg', 'audio/mp4', 'audio/wav', 'audio/m4a']),
    ('user-sheet-music', 'user-sheet-music', true, 10485760, ARRAY['application/pdf', 'image/jpeg', 'image/png']),
    ('analysis-results', 'analysis-results', true, 1048576, ARRAY['application/json', 'text/plain', 'audio/midi', 'image/png']);

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
```

### Step 2: Configure Environment Variables
```bash
# Copy the environment template
cp env.aws .env

# Edit .env with your actual values
nano .env
```

**Required values to set:**
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_KEY`: Your Supabase anon key
- `SUPABASE_SERVICE_ROLE_KEY`: Your Supabase service role key

### Step 3: Deploy to AWS
```bash
# Make deployment script executable
chmod +x deploy-to-aws.sh

# Deploy to production (default)
./deploy-to-aws.sh

# Deploy to staging
./deploy-to-aws.sh staging

# Deploy with custom domain
./deploy-to-aws.sh production us-east-1 api.yourdomain.com

# Deploy with SSL certificate
./deploy-to-aws.sh production us-east-1 api.yourdomain.com arn:aws:acm:us-east-1:123456789012:certificate/abcd1234
```

## 🔧 Manual Deployment Steps

If you prefer to deploy manually or need to troubleshoot:

### 1. Build and Push Docker Image
```bash
# Get ECR login token
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Build image
docker build -t tunein-backend .

# Tag for ECR
docker tag tunein-backend:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/tunein-cursor-production:latest

# Push to ECR
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/tunein-cursor-production:latest
```

### 2. Deploy CloudFormation Stack
```bash
# Create stack
aws cloudformation create-stack \
    --stack-name tunein-cursor-production \
    --template-body file://aws-deployment.yml \
    --parameters ParameterKey=Environment,ParameterValue=production \
    --capabilities CAPABILITY_NAMED_IAM \
    --region us-east-1

# Wait for completion
aws cloudformation wait stack-create-complete \
    --stack-name tunein-cursor-production \
    --region us-east-1
```

### 3. Configure ECS Environment Variables
```bash
# Get your Supabase credentials and update the ECS service
aws ecs update-service \
    --cluster tunein-production-cluster \
    --service tunein-production-backend \
    --region us-east-1

# You'll need to update the task definition with environment variables
# This is easier to do through the AWS Console or by updating the CloudFormation template
```

## 🔍 Verification and Testing

### 1. Check Stack Status
```bash
aws cloudformation describe-stacks \
    --stack-name tunein-cursor-production \
    --region us-east-1
```

### 2. Test Health Endpoint
```bash
# Get ALB DNS name
ALB_DNS=$(aws cloudformation describe-stacks \
    --stack-name tunein-cursor-production \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' \
    --output text)

# Test health endpoint
curl -f "http://$ALB_DNS/health"
```

### 3. Check ECS Service Status
```bash
aws ecs describe-services \
    --cluster tunein-production-cluster \
    --services tunein-production-backend \
    --region us-east-1
```

### 4. View Logs
```bash
aws logs tail /ecs/production-tunein-backend --follow --region us-east-1
```

## 📱 iOS App Updates

### 1. Update Backend URL
In `ContentView.swift`, update the backend URL:
```swift
// Replace the placeholder with your AWS domain
static let backendURL = "https://api.yourdomain.com"  // or your ALB DNS name
```

### 2. Test Authentication Flow
- Test signup with password confirmation
- Test password visibility toggle
- Verify Supabase integration

## 🛡️ Security Considerations

### Implemented Security Features
- ✅ HTTPS with SSL/TLS
- ✅ Security groups limiting access
- ✅ IAM roles with minimal permissions
- ✅ File type validation
- ✅ File size limits
- ✅ CORS configuration

### Additional Security Recommendations
- [ ] Enable AWS WAF for DDoS protection
- [ ] Set up CloudTrail for API logging
- [ ] Configure AWS Config for compliance monitoring
- [ ] Enable VPC Flow Logs for network monitoring
- [ ] Set up AWS GuardDuty for threat detection

## 📊 Monitoring and Alerting

### CloudWatch Alarms
```bash
# Create CPU utilization alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "tunein-cpu-high" \
    --alarm-description "High CPU utilization" \
    --metric-name CPUUtilization \
    --namespace AWS/ECS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --alarm-actions arn:aws:sns:us-east-1:123456789012:your-sns-topic
```

### Log Analysis
```bash
# Search for errors in logs
aws logs filter-log-events \
    --log-group-name /ecs/production-tunein-backend \
    --filter-pattern "ERROR" \
    --start-time $(date -d '1 hour ago' +%s)000
```

## 🔄 Updating the Deployment

### 1. Update Code and Rebuild
```bash
# Make your code changes
# Rebuild and push Docker image
docker build -t tunein-backend .
docker tag tunein-backend:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/tunein-cursor-production:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/tunein-cursor-production:latest
```

### 2. Force New Deployment
```bash
aws ecs update-service \
    --cluster tunein-production-cluster \
    --service tunein-production-backend \
    --force-new-deployment \
    --region us-east-1
```

## 🆘 Troubleshooting

### Common Issues

#### 1. ECS Tasks Not Starting
```bash
# Check task definition
aws ecs describe-task-definition \
    --task-definition tunein-production-backend \
    --region us-east-1

# Check service events
aws ecs describe-services \
    --cluster tunein-production-cluster \
    --services tunein-production-backend \
    --region us-east-1
```

#### 2. Health Check Failures
```bash
# Check container logs
aws logs tail /ecs/production-tunein-backend --follow --region us-east-1

# Verify health endpoint is accessible from within the container
aws ecs run-task \
    --cluster tunein-production-cluster \
    --task-definition tunein-production-backend \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[subnet-12345],securityGroups=[sg-12345],assignPublicIp=ENABLED}" \
    --region us-east-1
```

#### 3. File Upload Issues
- Check Supabase storage policies
- Verify bucket names match
- Check file size limits
- Verify CORS configuration

### Debug Commands
```bash
# Get all stack resources
aws cloudformation list-stack-resources \
    --stack-name tunein-cursor-production \
    --region us-east-1

# Get ECS service events
aws ecs describe-services \
    --cluster tunein-production-cluster \
    --services tunein-production-backend \
    --region us-east-1 \
    --query 'services[0].events'

# Check ALB target health
aws elbv2 describe-target-health \
    --target-group-arn $(aws cloudformation describe-stacks \
        --stack-name tunein-cursor-production \
        --region us-east-1 \
        --query 'Stacks[0].Outputs[?OutputKey==`ALBTargetGroupArn`].OutputValue' \
        --output text) \
    --region us-east-1
```

## 💰 Cost Optimization

### Estimated Monthly Costs
- **ECS Fargate**: $30-50/month (2 tasks, 0.5 vCPU, 1GB RAM)
- **Application Load Balancer**: $20/month
- **CloudWatch Logs**: $5-10/month
- **Data Transfer**: $5-15/month
- **ECR Storage**: $1-5/month

**Total: ~$60-100/month**

### Cost Optimization Tips
- Use FARGATE_SPOT for non-critical workloads
- Set up log retention policies
- Monitor and adjust resource allocation
- Use CloudWatch Insights for efficient log queries

## 🎯 Next Steps

### Immediate Actions
1. ✅ Deploy to AWS using the automated script
2. ✅ Test the health endpoint
3. ✅ Verify ECS service is running
4. ✅ Update iOS app with new backend URL
5. ✅ Test complete authentication flow

### Future Enhancements
- [ ] Set up CI/CD pipeline with GitHub Actions
- [ ] Add monitoring dashboards
- [ ] Implement auto-scaling policies
- [ ] Add backup and disaster recovery
- [ ] Set up staging environment

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review CloudWatch logs
3. Verify all environment variables are set
4. Ensure Supabase buckets are properly configured
5. Check AWS service quotas and limits

---

**🎉 Congratulations!** Your TuneIn Cursor backend is now deployed on AWS with proper Supabase integration and enhanced iOS authentication features.







