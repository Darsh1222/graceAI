#!/bin/bash

# Update backend environment with Supabase credentials
echo "Updating backend environment with Supabase credentials..."

# Supabase credentials
SUPABASE_URL="https://cjqmnznipjwdxgqdegov.supabase.co"
SUPABASE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNqcW1uem5pcGp3ZHhncWRlZ292Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ1MDQ5NzEsImV4cCI6MjA3MDA4MDk3MX0.2de1-z-UxDP9EkBq4DfGSponnioTLtOy1Vy4y9lsZWg"

# Update the backend environment file
cat > /Users/darshsenthil/Documents/TuneIn\ Cursor/TuneIn-Cursor-New/backend/.env << EOF
# Environment Configuration
ENVIRONMENT=production
DEBUG=false

# Server Configuration
HOST=0.0.0.0
PORT=8000

# File Upload Configuration
UPLOAD_FOLDER=/tmp/uploads
MAX_CONTENT_LENGTH=52428800  # 50MB in bytes

# Supabase Configuration
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_KEY=${SUPABASE_KEY}

# AWS Configuration (if using AWS services)
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=us-east-1
AWS_S3_BUCKET=your-s3-bucket-name

# Security
SECRET_KEY=your_secret_key_here
ALLOWED_ORIGINS=https://your-frontend-domain.com
EOF

echo "✅ Backend environment updated with Supabase credentials"
echo "🔑 Supabase URL: ${SUPABASE_URL}"
echo "🔑 Supabase Key: ${SUPABASE_KEY:0:20}..."
