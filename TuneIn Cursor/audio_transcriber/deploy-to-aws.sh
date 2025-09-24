#!/bin/bash

# TuneIn Cursor AWS Deployment Script
# This script automates the deployment of the TuneIn Cursor backend to AWS

set -e  # Exit on any error

# Configuration
ENVIRONMENT=${1:-production}
REGION=${2:-us-east-1}
DOMAIN_NAME=${3:-""}
CERTIFICATE_ARN=${4:-""}
STACK_NAME="tunein-cursor-${ENVIRONMENT}"

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
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install it first."
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
    log_info "Building and pushing Docker image..."
    
    # Get ECR login token
    log_info "Logging in to ECR..."
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
    
    # Build Docker image
    log_info "Building Docker image..."
    docker build -t tunein-backend .
    
    # Tag image for ECR
    docker tag tunein-backend:latest $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$STACK_NAME:latest
    
    # Push image to ECR
    log_info "Pushing image to ECR..."
    docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$STACK_NAME:latest
    
    log_success "Docker image built and pushed successfully!"
}

# Deploy CloudFormation stack
deploy_stack() {
    log_info "Deploying CloudFormation stack: $STACK_NAME"
    
    # Prepare CloudFormation parameters
    PARAMETERS="Environment=$ENVIRONMENT"
    
    if [ ! -z "$DOMAIN_NAME" ]; then
        PARAMETERS="$PARAMETERS DomainName=$DOMAIN_NAME"
    fi
    
    if [ ! -z "$CERTIFICATE_ARN" ]; then
        PARAMETERS="$PARAMETERS CertificateArn=$CERTIFICATE_ARN"
    fi
    
    # Deploy stack
    if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
        log_info "Stack exists, updating..."
        aws cloudformation update-stack \
            --stack-name $STACK_NAME \
            --template-body file://aws-deployment.yml \
            --parameters $PARAMETERS \
            --capabilities CAPABILITY_NAMED_IAM \
            --region $REGION
        
        log_info "Waiting for stack update to complete..."
        aws cloudformation wait stack-update-complete --stack-name $STACK_NAME --region $REGION
    else
        log_info "Creating new stack..."
        aws cloudformation create-stack \
            --stack-name $STACK_NAME \
            --template-body file://aws-deployment.yml \
            --parameters $PARAMETERS \
            --capabilities CAPABILITY_NAMED_IAM \
            --region $REGION
        
        log_info "Waiting for stack creation to complete..."
        aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION
    fi
    
    log_success "CloudFormation stack deployed successfully!"
}

# Get stack outputs
get_stack_outputs() {
    log_info "Getting stack outputs..."
    
    # Get ECR repository URI
    ECR_REPO_URI=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryURI`].OutputValue' \
        --output text)
    
    # Get ALB DNS name
    ALB_DNS=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' \
        --output text)
    
    # Get API domain
    API_DOMAIN=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[?OutputKey==`APIDomain`].OutputValue' \
        --output text)
    
    log_success "Stack outputs retrieved!"
    echo "ECR Repository URI: $ECR_REPO_URI"
    echo "ALB DNS Name: $ALB_DNS"
    echo "API Domain: $API_DOMAIN"
}

# Test deployment
test_deployment() {
    log_info "Testing deployment..."
    
    # Wait a bit for the service to be ready
    sleep 30
    
    # Get ALB DNS name
    ALB_DNS=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' \
        --output text)
    
    # Test health endpoint
    log_info "Testing health endpoint..."
    if curl -f "http://$ALB_DNS/health" > /dev/null 2>&1; then
        log_success "Health endpoint is working!"
    else
        log_warning "Health endpoint is not responding yet. This might be normal during startup."
    fi
    
    # Check ECS service status
    log_info "Checking ECS service status..."
    SERVICE_STATUS=$(aws ecs describe-services \
        --cluster tunein-$ENVIRONMENT-cluster \
        --services tunein-$ENVIRONMENT-backend \
        --region $REGION \
        --query 'services[0].status' \
        --output text)
    
    log_info "ECS service status: $SERVICE_STATUS"
    
    # Check running tasks
    RUNNING_TASKS=$(aws ecs describe-services \
        --cluster tunein-$ENVIRONMENT-cluster \
        --services tunein-$ENVIRONMENT-backend \
        --region $REGION \
        --query 'services[0].runningCount' \
        --output text)
    
    log_info "Running tasks: $RUNNING_TASKS"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    
    # Stop any running containers
    docker stop $(docker ps -q) 2>/dev/null || true
    docker rm $(docker ps -aq) 2>/dev/null || true
    
    log_success "Cleanup completed!"
}

# Main deployment function
main() {
    log_info "Starting TuneIn Cursor AWS deployment..."
    log_info "Environment: $ENVIRONMENT"
    log_info "Region: $REGION"
    log_info "Stack Name: $STACK_NAME"
    
    # Get AWS account ID
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    log_info "AWS Account ID: $AWS_ACCOUNT_ID"
    
    # Check prerequisites
    check_prerequisites
    
    # Build and push Docker image
    build_and_push_image
    
    # Deploy CloudFormation stack
    deploy_stack
    
    # Get stack outputs
    get_stack_outputs
    
    # Test deployment
    test_deployment
    
    log_success "Deployment completed successfully!"
    
    # Display final information
    echo ""
    echo "🎉 TuneIn Cursor Backend deployed successfully!"
    echo ""
    echo "📋 Deployment Summary:"
    echo "   Environment: $ENVIRONMENT"
    echo "   Region: $REGION"
    echo "   Stack Name: $STACK_NAME"
    echo ""
    echo "🔗 Next Steps:"
    echo "   1. Update your iOS app with the new API endpoint"
    echo "   2. Configure Supabase environment variables in AWS ECS"
    echo "   3. Test the complete authentication and analysis flow"
    echo ""
    echo "📚 Useful Commands:"
    echo "   View stack: aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION"
    echo "   View logs: aws logs tail /ecs/$ENVIRONMENT-tunein-backend --follow --region $REGION"
    echo "   Update service: aws ecs update-service --cluster tunein-$ENVIRONMENT-cluster --service tunein-$ENVIRONMENT-backend --region $REGION"
}

# Trap cleanup on script exit
trap cleanup EXIT

# Check if help is requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: $0 [ENVIRONMENT] [REGION] [DOMAIN_NAME] [CERTIFICATE_ARN]"
    echo ""
    echo "Parameters:"
    echo "  ENVIRONMENT      Environment name (default: production)"
    echo "  REGION          AWS region (default: us-east-1)"
    echo "  DOMAIN_NAME     Domain name for the API (optional)"
    echo "  CERTIFICATE_ARN ARN of SSL certificate (optional)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Deploy to production in us-east-1"
    echo "  $0 staging us-west-2                 # Deploy to staging in us-west-2"
    echo "  $0 production us-east-1 api.example.com arn:aws:acm:us-east-1:123456789012:certificate/abcd1234"
    exit 0
fi

# Run main function
main "$@"
