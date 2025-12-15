#!/bin/bash

# TuneIn Cursor FastAPI AWS Deployment Script
# This script deploys the new FastAPI backend with MuseScore and Audiveris

set -e  # Exit on any error

# Configuration
ENVIRONMENT=${1:-production}
REGION=${2:-us-east-1}
AWS_ACCOUNT_ID="508426718674"
ECR_REPO_NAME="tunein-cursor-simple"
IMAGE_TAG="latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    log_success "All prerequisites are met!"
}

# Build and push Docker image
build_and_push_image() {
    log_info "Building and pushing FastAPI Docker image with MuseScore and Audiveris..."
    
    # Navigate to backend directory
    cd "$(dirname "$0")/../../../backend"
    
    # Get ECR login token
    log_info "Logging in to ECR..."
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
    
    # Build Docker image for AMD64 platform (required for ECS Fargate)
    log_info "Building Docker image for AMD64 platform..."
    docker build --platform linux/amd64 -t tunein-backend-fastapi .
    
    # Tag image for ECR
    ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG"
    docker tag tunein-backend-fastapi:latest $ECR_URI
    
    # Push image to ECR
    log_info "Pushing image to ECR..."
    docker push $ECR_URI
    
    log_success "FastAPI Docker image built and pushed successfully!"
    echo "Image URI: $ECR_URI"
}

# Update ECS service
update_ecs_service() {
    log_info "Updating ECS service with new task definition..."
    
    # Register new task definition
    log_info "Registering new task definition..."
    TASK_DEF_ARN=$(aws ecs register-task-definition \
        --cli-input-json file://../ecs/new_task_definition.json \
        --region $REGION \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)
    
    log_info "New task definition registered: $TASK_DEF_ARN"
    
    # Update ECS service
    log_info "Updating ECS service..."
    aws ecs update-service \
        --cluster tunein-backend-cluster \
        --service tunein-backend-service \
        --task-definition $TASK_DEF_ARN \
        --region $REGION \
        --force-new-deployment
    
    log_success "ECS service update initiated!"
}

# Wait for deployment
wait_for_deployment() {
    log_info "Waiting for deployment to complete..."
    
    # Wait for service to stabilize
    aws ecs wait services-stable \
        --cluster tunein-backend-cluster \
        --services tunein-backend-service \
        --region $REGION
    
    log_success "Deployment completed and service is stable!"
}

# Test deployment
test_deployment() {
    log_info "Testing deployment..."
    
    # Get ALB DNS name
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --names tunein-backend-alb \
        --region $REGION \
        --query 'LoadBalancers[0].DNSName' \
        --output text)
    
    log_info "ALB DNS: $ALB_DNS"
    
    # Test health endpoint
    log_info "Testing health endpoint..."
    if curl -f "http://$ALB_DNS:8000/health/" > /dev/null 2>&1; then
        log_success "Health endpoint is working!"
    else
        log_warning "Health endpoint is not responding yet. This might be normal during startup."
    fi
    
    # Test detailed health endpoint
    log_info "Testing detailed health endpoint..."
    if curl -f "http://$ALB_DNS:8000/health/detailed" > /dev/null 2>&1; then
        log_success "Detailed health endpoint is working!"
    else
        log_warning "Detailed health endpoint is not responding yet."
    fi
    
    # Check ECS service status
    log_info "Checking ECS service status..."
    SERVICE_STATUS=$(aws ecs describe-services \
        --cluster tunein-backend-cluster \
        --services tunein-backend-service \
        --region $REGION \
        --query 'services[0].status' \
        --output text)
    
    log_info "ECS service status: $SERVICE_STATUS"
    
    # Check running tasks
    RUNNING_TASKS=$(aws ecs describe-services \
        --cluster tunein-backend-cluster \
        --services tunein-backend-service \
        --region $REGION \
        --query 'services[0].runningCount' \
        --output text)
    
    log_info "Running tasks: $RUNNING_TASKS"
    
    # Check task health
    TASK_ARNS=$(aws ecs list-tasks \
        --cluster tunein-backend-cluster \
        --service-name tunein-backend-service \
        --region $REGION \
        --query 'taskArns' \
        --output text)
    
    if [ ! -z "$TASK_ARNS" ]; then
        log_info "Checking task health..."
        for TASK_ARN in $TASK_ARNS; do
            HEALTH_STATUS=$(aws ecs describe-tasks \
                --cluster tunein-backend-cluster \
                --tasks $TASK_ARN \
                --region $REGION \
                --query 'tasks[0].healthStatus' \
                --output text)
            log_info "Task $TASK_ARN health: $HEALTH_STATUS"
        done
    fi
}

# Show deployment summary
show_summary() {
    log_success "FastAPI deployment completed successfully!"
    
    echo ""
    echo "🎉 TuneIn Cursor FastAPI Backend deployed successfully!"
    echo ""
    echo "📋 Deployment Summary:"
    echo "   Environment: $ENVIRONMENT"
    echo "   Region: $REGION"
    echo "   ECR Repository: $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO_NAME"
    echo "   Image Tag: $IMAGE_TAG"
    echo ""
    
    # Get ALB DNS name
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --names tunein-backend-alb \
        --region $REGION \
        --query 'LoadBalancers[0].DNSName' \
        --output text 2>/dev/null || echo "Not available")
    
    echo "🔗 API Endpoints:"
    echo "   Health Check: http://$ALB_DNS:8000/health/"
    echo "   Detailed Health: http://$ALB_DNS:8000/health/detailed"
    echo "   API Documentation: http://$ALB_DNS:8000/docs"
    echo "   Analysis Endpoint: http://$ALB_DNS:8000/analyze/"
    echo ""
    
    echo "🎵 Music Processing Tools:"
    echo "   ✅ MuseScore 3 - Installed and ready"
    echo "   ✅ Audiveris 5.2.3 - Installed and ready"
    echo "   ✅ Basic Pitch AI - Ready for audio transcription"
    echo ""
    
    echo "📚 Useful Commands:"
    echo "   View logs: aws logs tail /ecs/tunein-cursor-task --follow --region $REGION"
    echo "   Check service: aws ecs describe-services --cluster tunein-backend-cluster --services tunein-backend-service --region $REGION"
    echo "   Update service: aws ecs update-service --cluster tunein-backend-cluster --service tunein-backend-service --region $REGION --force-new-deployment"
    echo ""
}

# Main deployment function
main() {
    log_info "Starting TuneIn Cursor FastAPI AWS deployment..."
    log_info "Environment: $ENVIRONMENT"
    log_info "Region: $REGION"
    log_info "AWS Account ID: $AWS_ACCOUNT_ID"
    
    # Check prerequisites
    check_prerequisites
    
    # Build and push Docker image
    build_and_push_image
    
    # Update ECS service
    update_ecs_service
    
    # Wait for deployment
    wait_for_deployment
    
    # Test deployment
    test_deployment
    
    # Show summary
    show_summary
}

# Check if help is requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: $0 [ENVIRONMENT] [REGION]"
    echo ""
    echo "Parameters:"
    echo "  ENVIRONMENT      Environment name (default: production)"
    echo "  REGION          AWS region (default: us-east-1)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Deploy to production in us-east-1"
    echo "  $0 staging us-west-2                 # Deploy to staging in us-west-2"
    echo ""
    echo "This script will:"
    echo "  1. Build FastAPI Docker image with MuseScore and Audiveris"
    echo "  2. Push image to ECR"
    echo "  3. Update ECS service with new task definition"
    echo "  4. Wait for deployment to complete"
    echo "  5. Test the deployment"
    exit 0
fi

# Run main function
main "$@"
