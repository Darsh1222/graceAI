#!/bin/bash

# Deploy to GraceAI ECR repository
set -e

# Configuration
ECR_REPO_URI="508426718674.dkr.ecr.us-east-1.amazonaws.com/graceai-app"
REGION="us-east-1"
IMAGE_TAG="latest"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_info "Starting GraceAI backend deployment..."

# Login to ECR
log_info "Logging in to ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REPO_URI

# Build Docker image
log_info "Building Docker image..."
docker build -t graceai-backend:$IMAGE_TAG .

# Tag image for ECR
log_info "Tagging image for ECR..."
docker tag graceai-backend:$IMAGE_TAG $ECR_REPO_URI:$IMAGE_TAG

# Push image to ECR
log_info "Pushing image to ECR..."
docker push $ECR_REPO_URI:$IMAGE_TAG

log_success "Image pushed to ECR successfully!"
log_info "ECR Repository: $ECR_REPO_URI"
log_info "Image Tag: $IMAGE_TAG"

# Check if there's a running ECS service to update
log_info "Checking for running ECS services..."
ECS_SERVICES=$(aws ecs list-services --cluster tunein-cursor-cluster --region $REGION --query 'serviceArns[]' --output text 2>/dev/null || echo "")

if [ -n "$ECS_SERVICES" ]; then
    log_info "Found ECS services. You may need to update the service to use the new image."
    log_warning "To update the service, run:"
    echo "aws ecs update-service --cluster tunein-cursor-cluster --service <service-name> --force-new-deployment --region $REGION"
else
    log_info "No ECS services found. The image is ready for deployment."
fi

log_success "Deployment completed!"


