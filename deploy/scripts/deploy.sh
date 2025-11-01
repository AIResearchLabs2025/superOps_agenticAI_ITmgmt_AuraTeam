#!/bin/bash
# Universal Deployment Script for Aura Team Project
# Supports local development and multiple cloud platforms

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [ENVIRONMENT] [CLOUD_PROVIDER] [DEPLOYMENT_TYPE]"
    echo ""
    echo "ENVIRONMENT:"
    echo "  local       - Local development with Docker Compose"
    echo "  dev         - Development environment"
    echo "  staging     - Staging environment"
    echo "  prod        - Production environment"
    echo ""
    echo "CLOUD_PROVIDER (optional for non-local):"
    echo "  aws         - Amazon Web Services (ECS/Fargate)"
    echo "  gcp         - Google Cloud Platform (GKE)"
    echo "  azure       - Microsoft Azure (AKS)"
    echo ""
    echo "DEPLOYMENT_TYPE (for cloud deployments):"
    echo "  backend     - Deploy only backend services (default)"
    echo "  frontend    - Deploy only frontend (requires backend running)"
    echo "  fullstack   - Deploy complete application (backend + frontend)"
    echo ""
    echo "Examples:"
    echo "  $0 local                        # Local development"
    echo "  $0 dev aws backend              # Deploy backend only to AWS"
    echo "  $0 dev aws fullstack            # Deploy complete application to AWS"
    echo "  $0 dev aws frontend             # Deploy only frontend to AWS"
    echo "  $0 staging gcp fullstack        # Deploy complete application to GCP"
    echo ""
    exit 1
}

# Function to check prerequisites
check_prerequisites() {
    local environment=$1
    local cloud_provider=$2
    
    print_header "Checking Prerequisites"
    
    # Common prerequisites
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose."
        exit 1
    fi
    
    # Cloud-specific prerequisites
    if [[ "$environment" != "local" ]]; then
        case $cloud_provider in
            "aws")
                if ! command -v aws &> /dev/null; then
                    print_error "AWS CLI is not installed. Please install AWS CLI."
                    exit 1
                fi
                
                # Check AWS credentials
                if ! aws sts get-caller-identity &> /dev/null; then
                    print_error "AWS credentials not configured. Run 'aws configure'."
                    exit 1
                fi
                ;;
            "gcp")
                if ! command -v gcloud &> /dev/null; then
                    print_error "Google Cloud SDK is not installed."
                    exit 1
                fi
                ;;
            "azure")
                if ! command -v az &> /dev/null; then
                    print_error "Azure CLI is not installed."
                    exit 1
                fi
                ;;
        esac
    fi
    
    print_status "All prerequisites checked ✓"
}

# Function to load environment variables
load_environment() {
    local environment=$1
    local env_file="deploy/environments/${environment}/.env"
    
    print_status "Loading environment configuration for: $environment"
    
    if [[ -f "$env_file" ]]; then
        set -a
        source "$env_file"
        set +a
        print_status "Environment variables loaded from $env_file"
    else
        print_warning "Environment file $env_file not found. Using defaults."
    fi
    
    # Ensure OPENAI_API_KEY is set for non-local environments
    if [[ "$environment" != "local" && -z "$OPENAI_API_KEY" ]]; then
        print_error "OPENAI_API_KEY is required for cloud deployments."
        print_status "Please set it in $env_file or as an environment variable."
        exit 1
    fi
}

# Function for local deployment
deploy_local() {
    print_header "Deploying to Local Environment"
    
    cd "$(dirname "$0")/../.." # Go to project root
    
    # Check if .env exists in aura-backend
    if [[ ! -f "aura-backend/.env" ]]; then
        print_status "Creating .env file from template..."
        cp aura-backend/.env.example aura-backend/.env
        print_warning "Please update aura-backend/.env with your OpenAI API key"
    fi
    
    # Use local docker-compose configuration
    print_status "Starting local services with Docker Compose..."
    docker-compose -f deploy/environments/local/docker-compose.yml up -d --build
    
    # Wait for services to be healthy
    print_status "Waiting for services to be healthy..."
    sleep 30
    
    # Check service health
    check_local_health
    
    print_status "Local deployment completed!"
    print_status "Access the application at:"
    print_status "  - API Gateway: http://localhost:8000"
    print_status "  - Service Desk: http://localhost:8001"
    print_status "  - Frontend: http://localhost:3000 (start separately)"
    print_status "  - API Docs: http://localhost:8000/docs"
}

# Function to check local service health
check_local_health() {
    print_status "Checking service health..."
    
    local max_attempts=10
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s http://localhost:8000/health > /dev/null && \
           curl -s http://localhost:8001/health > /dev/null; then
            print_status "All services are healthy ✓"
            return 0
        fi
        
        print_status "Attempt $attempt/$max_attempts - Services not ready yet..."
        sleep 10
        ((attempt++))
    done
    
    print_warning "Services may not be fully ready. Check logs with:"
    print_status "docker-compose -f deploy/environments/local/docker-compose.yml logs"
}

# Function for AWS deployment
deploy_aws() {
    local environment=$1
    local deployment_type=${2:-backend}
    
    print_header "Deploying to AWS Environment: $environment ($deployment_type)"
    
    # Set AWS region
    export AWS_DEFAULT_REGION=us-east-2
    
    # Create ECR repositories if they don't exist
    create_ecr_repositories
    
    # Determine if frontend should be included
    local include_frontend=false
    if [[ "$deployment_type" == "fullstack" || "$deployment_type" == "frontend" ]]; then
        include_frontend=true
    fi
    
    # Build and push Docker images
    build_and_push_images "aws" "$deployment_type"
    
    # Deploy to ECS
    deploy_to_ecs "$environment" "$deployment_type"
    
    print_status "AWS deployment completed!"
}

# Function to create ECR repositories
create_ecr_repositories() {
    print_status "Creating ECR repositories..."
    
    local repositories=("aura-api-gateway" "aura-service-desk-host" "aura-databases" "aura-frontend")
    
    for repo in "${repositories[@]}"; do
        if ! aws ecr describe-repositories --repository-names "$repo" &> /dev/null; then
            print_status "Creating ECR repository: $repo"
            aws ecr create-repository --repository-name "$repo" --region us-east-2
        else
            print_status "ECR repository already exists: $repo"
        fi
    done
}

# Function to build and push Docker images
build_and_push_images() {
    local cloud_provider=$1
    local deployment_type=${2:-backend}
    
    print_header "Building and Pushing Docker Images"
    
    # Get AWS account ID
    local aws_account_id=$(aws sts get-caller-identity --query Account --output text)
    local ecr_uri="${aws_account_id}.dkr.ecr.us-east-2.amazonaws.com"
    
    # Login to ECR
    print_status "Logging into ECR..."
    aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin "$ecr_uri"
    
    cd "$(dirname "$0")/../.." # Go to project root
    
    # Build based on deployment type
    if [[ "$deployment_type" == "frontend" ]]; then
        # Frontend-only deployment
        print_status "Building Frontend image only..."
        
        # Set API URL for production build
        export REACT_APP_API_BASE_URL="http://127.0.0.1:8000"
        
        docker build --platform linux/amd64 -t aura-frontend aura-frontend/
        docker tag aura-frontend:latest "$ecr_uri/aura-frontend:latest"
        docker push "$ecr_uri/aura-frontend:latest"
        
        print_status "Frontend image built and pushed ✓"
    else
        # Backend or fullstack deployment
        # Build and push API Gateway
        print_status "Building API Gateway image..."
        docker build --platform linux/amd64 -f aura-backend/api-gateway/Dockerfile -t aura-api-gateway aura-backend/
        docker tag aura-api-gateway:latest "$ecr_uri/aura-api-gateway:latest"
        docker push "$ecr_uri/aura-api-gateway:latest"
        
        # Build and push Service Desk Host
        print_status "Building Service Desk Host image..."
        docker build --platform linux/amd64 -f aura-backend/service-desk-host/Dockerfile -t aura-service-desk-host aura-backend/
        docker tag aura-service-desk-host:latest "$ecr_uri/aura-service-desk-host:latest"
        docker push "$ecr_uri/aura-service-desk-host:latest"
        
        # Build and push Multi-Database
        print_status "Building Multi-Database image..."
        docker build --platform linux/amd64 -t aura-databases deploy/containers/multi-database/
        docker tag aura-databases:latest "$ecr_uri/aura-databases:latest"
        docker push "$ecr_uri/aura-databases:latest"
        
        # Build and push Frontend (if fullstack)
        if [[ "$deployment_type" == "fullstack" ]]; then
            print_status "Building Frontend image..."
            
            # Set API URL for production build
            export REACT_APP_API_BASE_URL="http://127.0.0.1:8000"
            
            docker build --platform linux/amd64 -t aura-frontend aura-frontend/
            docker tag aura-frontend:latest "$ecr_uri/aura-frontend:latest"
            docker push "$ecr_uri/aura-frontend:latest"
            
            print_status "Frontend image built and pushed ✓"
        fi
    fi
    
    print_status "All required images built and pushed successfully ✓"
}

# Function to deploy to ECS
deploy_to_ecs() {
    local environment=$1
    local deployment_type=${2:-backend}
    
    print_status "Deploying to ECS..."
    
    # Check if infrastructure file exists
    local infrastructure_file="deploy/aws/infrastructure-${environment}.json"
    if [[ ! -f "$infrastructure_file" ]]; then
        print_error "Infrastructure file not found: $infrastructure_file"
        print_status "Please run setup-aws-infrastructure.sh first:"
        print_status "  ./deploy/scripts/setup-aws-infrastructure.sh $environment"
        exit 1
    fi
    
    # Load infrastructure configuration
    local vpc_id=$(jq -r '.vpc_id' "$infrastructure_file")
    local public_subnets=$(jq -r '.public_subnets | join(",")' "$infrastructure_file")
    local security_group_id=$(jq -r '.security_group_id' "$infrastructure_file")
    local cluster_name=$(jq -r '.ecs_cluster' "$infrastructure_file")
    
    print_status "Using infrastructure configuration:"
    print_status "  VPC: $vpc_id"
    print_status "  Subnets: $public_subnets"
    print_status "  Security Group: $security_group_id"
    print_status "  ECS Cluster: $cluster_name"
    
    # Select appropriate task definition and service name based on deployment type
    local task_def_file
    local service_name
    local task_family
    
    case "$deployment_type" in
        "frontend")
            task_def_file="deploy/aws/ecs/task-definition-frontend-only.json"
            service_name="aura-frontend-service"
            task_family="aura-frontend-${environment}"
            print_status "Using frontend-only task definition"
            ;;
        "fullstack")
            task_def_file="deploy/aws/ecs/task-definition-with-frontend.json"
            service_name="aura-app-service"
            task_family="aura-app-${environment}"
            print_status "Using fullstack task definition with frontend"
            ;;
        *)
            task_def_file="deploy/aws/ecs/task-definition.json"
            service_name="aura-app-service"
            task_family="aura-app-${environment}"
            print_status "Using backend-only task definition"
            ;;
    esac
    
    # Update task definition with current AWS account ID
    local aws_account_id=$(aws sts get-caller-identity --query Account --output text)
    local updated_task_def="/tmp/task-definition-${environment}.json"
    
    # Replace account ID in task definition
    sed "s/753353727891/$aws_account_id/g" "$task_def_file" > "$updated_task_def"
    
    # Create CloudWatch log group
    local log_group="/ecs/aura-app-${environment}"
    if ! aws logs describe-log-groups --log-group-name-prefix "$log_group" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$log_group"; then
        print_status "Creating CloudWatch log group: $log_group"
        aws logs create-log-group --log-group-name "$log_group"
        aws logs put-retention-policy --log-group-name "$log_group" --retention-in-days 7
    fi
    
    # Register task definition
    print_status "Registering ECS task definition with account ID: $aws_account_id"
    local task_def_arn=$(aws ecs register-task-definition --cli-input-json file://"$updated_task_def" --query 'taskDefinition.taskDefinitionArn' --output text)
    print_status "Task definition registered: $task_def_arn"
    
    # Create or update ECS service
    if aws ecs describe-services --cluster "$cluster_name" --services "$service_name" --query 'services[0].status' --output text 2>/dev/null | grep -q ACTIVE; then
        print_status "Updating existing ECS service: $service_name"
        aws ecs update-service \
            --cluster "$cluster_name" \
            --service "$service_name" \
            --task-definition "$task_family" \
            --region "$AWS_DEFAULT_REGION"
    else
        print_status "Creating new ECS service: $service_name"
        aws ecs create-service \
            --cluster "$cluster_name" \
            --service-name "$service_name" \
            --task-definition "$task_family" \
            --desired-count 1 \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[$public_subnets],securityGroups=[$security_group_id],assignPublicIp=ENABLED}" \
            --region "$AWS_DEFAULT_REGION"
    fi
    
    # Wait for service to stabilize
    print_status "Waiting for ECS service to stabilize..."
    aws ecs wait services-stable --cluster "$cluster_name" --services "$service_name" --region "$AWS_DEFAULT_REGION"
    
    # Get service status and public IP
    print_status "Getting service details..."
    local task_arns=$(aws ecs list-tasks --cluster "$cluster_name" --service-name "$service_name" --query 'taskArns[0]' --output text --region "$AWS_DEFAULT_REGION")
    
    if [[ "$task_arns" != "None" && "$task_arns" != "null" ]]; then
        local public_ip=$(aws ecs describe-tasks --cluster "$cluster_name" --tasks "$task_arns" --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text --region "$AWS_DEFAULT_REGION" | xargs -I {} aws ec2 describe-network-interfaces --network-interface-ids {} --query 'NetworkInterfaces[0].Association.PublicIp' --output text --region "$AWS_DEFAULT_REGION")
        
        if [[ "$public_ip" != "None" && "$public_ip" != "null" ]]; then
            print_status "Application deployed successfully!"
            print_status "Access your application at:"
            if [[ "$deployment_type" == "frontend" || "$deployment_type" == "fullstack" ]]; then
                print_status "  - 🌐 Frontend UI: http://$public_ip:80"
            fi
            print_status "  - 🔌 API Gateway: http://$public_ip:8000"
            print_status "  - 🎫 Service Desk: http://$public_ip:8001"
            print_status "  - 📚 API Documentation: http://$public_ip:8000/docs"
        fi
    fi
    
    # Clean up temp file
    rm -f "$updated_task_def"
    
    print_status "ECS deployment completed!"
}

# Function to stop/cleanup deployment
cleanup_deployment() {
    local environment=$1
    
    print_header "Cleaning up deployment: $environment"
    
    if [[ "$environment" == "local" ]]; then
        cd "$(dirname "$0")/../.."
        docker-compose -f deploy/environments/local/docker-compose.yml down -v
        print_status "Local services stopped and volumes removed."
    else
        print_warning "Cloud cleanup not implemented. Use cloud provider console."
    fi
}

# Main script logic
main() {
    # Parse arguments
    local environment="${1:-}"
    local cloud_provider="${2:-}"
    
    # Show usage if no arguments
    if [[ -z "$environment" ]]; then
        show_usage
    fi
    
    # Validate environment
    case $environment in
        "local"|"dev"|"staging"|"prod")
            ;;
        "cleanup")
            cleanup_deployment "${2:-local}"
            exit 0
            ;;
        *)
            print_error "Invalid environment: $environment"
            show_usage
            ;;
    esac
    
    # Set default cloud provider for non-local environments
    if [[ "$environment" != "local" && -z "$cloud_provider" ]]; then
        cloud_provider="aws"
        print_warning "No cloud provider specified. Defaulting to AWS."
    fi
    
    # Parse deployment type for cloud deployments
    local deployment_type="backend"
    if [[ "$environment" != "local" ]]; then
        case "${3:-}" in
            "fullstack"|"full")
                deployment_type="fullstack"
                ;;
            "frontend")
                deployment_type="frontend"
                ;;
            "backend"|"")
                deployment_type="backend"
                ;;
            *)
                print_error "Invalid deployment type: ${3:-}. Use: backend, frontend, or fullstack"
                show_usage
                ;;
        esac
    fi
    
    print_header "Aura Team Project Deployment"
    print_status "Environment: $environment"
    if [[ "$environment" != "local" ]]; then
        print_status "Cloud Provider: $cloud_provider"
        print_status "Deployment Type: $deployment_type"
    fi
    
    # Check prerequisites
    check_prerequisites "$environment" "$cloud_provider"
    
    # Load environment configuration
    load_environment "$environment"
    
    # Deploy based on environment
    case $environment in
        "local")
            deploy_local
            ;;
        *)
            case $cloud_provider in
                "aws")
                    deploy_aws "$environment" "$deployment_type"
                    ;;
                "gcp"|"azure")
                    print_error "Deployment to $cloud_provider not implemented yet."
                    exit 1
                    ;;
                *)
                    print_error "Invalid cloud provider: $cloud_provider"
                    show_usage
                    ;;
            esac
            ;;
    esac
}

# Run main function with all arguments
main "$@"
