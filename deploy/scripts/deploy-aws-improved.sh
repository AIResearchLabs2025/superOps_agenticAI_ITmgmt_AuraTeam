#!/bin/bash
# Improved AWS Deployment Script for Aura Team Project
# Handles cleanup, health checks, and prevents task recreation loops

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
    echo "Usage: $0 [ENVIRONMENT] [DEPLOYMENT_TYPE] [OPTIONS]"
    echo ""
    echo "ENVIRONMENT:"
    echo "  dev         - Development environment (default)"
    echo "  staging     - Staging environment"
    echo "  prod        - Production environment"
    echo ""
    echo "DEPLOYMENT_TYPE:"
    echo "  backend     - Deploy only backend services (default)"
    echo "  frontend    - Deploy only frontend"
    echo "  fullstack   - Deploy complete application"
    echo ""
    echo "OPTIONS:"
    echo "  --cleanup-first    - Clean up existing services before deployment"
    echo "  --force           - Skip confirmation prompts"
    echo "  --no-build        - Skip Docker image building (use existing images)"
    echo "  --health-timeout  - Health check timeout in seconds (default: 300)"
    echo ""
    echo "Examples:"
    echo "  $0 dev backend --cleanup-first    # Clean up and deploy backend"
    echo "  $0 dev fullstack --force          # Force deploy complete app"
    echo "  $0 staging backend --no-build     # Deploy without rebuilding images"
    echo ""
    exit 1
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI."
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker."
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install jq for JSON processing."
        exit 1
    fi
    
    # Check AWS credentials
    print_status "Checking AWS credentials..."
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured or expired."
        print_status "Please run 'aws configure' or refresh your credentials."
        print_status "If using SSO, run: aws sso login --profile your-profile"
        exit 1
    fi
    
    # Get AWS account info
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=${AWS_DEFAULT_REGION:-us-east-2}
    
    print_status "AWS Account ID: $AWS_ACCOUNT_ID"
    print_status "AWS Region: $AWS_REGION"
    print_status "All prerequisites checked ✓"
}

# Function to load infrastructure configuration
load_infrastructure() {
    local environment=$1
    
    print_status "Loading infrastructure configuration for: $environment"
    
    local infrastructure_file="deploy/aws/infrastructure-${environment}.json"
    if [[ ! -f "$infrastructure_file" ]]; then
        print_error "Infrastructure file not found: $infrastructure_file"
        print_status "Please run setup-aws-infrastructure.sh first:"
        print_status "  ./deploy/scripts/setup-aws-infrastructure.sh $environment"
        exit 1
    fi
    
    # Load infrastructure variables
    VPC_ID=$(jq -r '.vpc_id' "$infrastructure_file")
    PUBLIC_SUBNETS=$(jq -r '.public_subnets | join(",")' "$infrastructure_file")
    SECURITY_GROUP_ID=$(jq -r '.security_group_id' "$infrastructure_file")
    CLUSTER_NAME=$(jq -r '.ecs_cluster' "$infrastructure_file")
    
    print_status "Infrastructure loaded:"
    print_status "  VPC: $VPC_ID"
    print_status "  Subnets: $PUBLIC_SUBNETS"
    print_status "  Security Group: $SECURITY_GROUP_ID"
    print_status "  ECS Cluster: $CLUSTER_NAME"
}

# Function to cleanup existing services
cleanup_existing_services() {
    local environment=$1
    local force=$2
    
    print_header "Cleaning Up Existing Services"
    
    # List of possible service names
    local service_names=("aura-app-service" "aura-frontend-service" "aura-backend-service")
    local services_to_cleanup=()
    
    # Check which services exist
    for service_name in "${service_names[@]}"; do
        local service_status=$(aws ecs describe-services \
            --cluster "$CLUSTER_NAME" \
            --services "$service_name" \
            --query 'services[0].status' \
            --output text 2>/dev/null || echo "NONE")
        
        if [[ "$service_status" != "NONE" && "$service_status" != "null" ]]; then
            services_to_cleanup+=("$service_name")
            print_status "Found existing service: $service_name ($service_status)"
        fi
    done
    
    if [[ ${#services_to_cleanup[@]} -eq 0 ]]; then
        print_status "No existing services found to clean up ✓"
        return 0
    fi
    
    # Confirm cleanup unless force is specified
    if [[ "$force" != "true" ]]; then
        echo ""
        print_warning "Found ${#services_to_cleanup[@]} existing services to clean up:"
        for service in "${services_to_cleanup[@]}"; do
            echo "  - $service"
        done
        echo ""
        read -p "Do you want to clean up these services before deployment? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Cleanup skipped by user"
            return 0
        fi
    fi
    
    # Cleanup services
    for service_name in "${services_to_cleanup[@]}"; do
        print_status "Cleaning up service: $service_name"
        
        # Scale down to 0
        print_status "  Scaling down to 0 tasks..."
        aws ecs update-service \
            --cluster "$CLUSTER_NAME" \
            --service "$service_name" \
            --desired-count 0 \
            --region "$AWS_REGION" > /dev/null
        
        # Wait for scale down
        print_status "  Waiting for service to scale down..."
        aws ecs wait services-stable \
            --cluster "$CLUSTER_NAME" \
            --services "$service_name" \
            --region "$AWS_REGION"
        
        # Delete service
        print_status "  Deleting service..."
        aws ecs delete-service \
            --cluster "$CLUSTER_NAME" \
            --service "$service_name" \
            --region "$AWS_REGION" > /dev/null
        
        print_status "Service $service_name cleaned up ✓"
    done
    
    # Force stop any remaining tasks
    local tasks=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --query 'taskArns' --output text 2>/dev/null || echo "")
    if [[ -n "$tasks" && "$tasks" != "None" ]]; then
        print_status "Force stopping remaining tasks..."
        for task_arn in $tasks; do
            aws ecs stop-task --cluster "$CLUSTER_NAME" --task "$task_arn" --reason "Cleanup before deployment" > /dev/null
        done
    fi
    
    print_status "Cleanup completed ✓"
}

# Function to create ECR repositories
create_ecr_repositories() {
    print_status "Creating ECR repositories..."
    
    local repositories=("aura-api-gateway" "aura-service-desk-host" "aura-databases" "aura-frontend")
    
    for repo in "${repositories[@]}"; do
        if ! aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" &> /dev/null; then
            print_status "Creating ECR repository: $repo"
            aws ecr create-repository --repository-name "$repo" --region "$AWS_REGION" > /dev/null
        else
            print_status "ECR repository already exists: $repo"
        fi
    done
}

# Function to build and push Docker images
build_and_push_images() {
    local deployment_type=$1
    local skip_build=$2
    
    if [[ "$skip_build" == "true" ]]; then
        print_status "Skipping Docker image building (--no-build specified)"
        return 0
    fi
    
    print_header "Building and Pushing Docker Images"
    
    local ecr_uri="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    
    # Login to ECR
    print_status "Logging into ECR..."
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ecr_uri"
    
    cd "$(dirname "$0")/../.." # Go to project root
    
    # Build based on deployment type
    if [[ "$deployment_type" == "frontend" ]]; then
        # Frontend-only deployment
        print_status "Building Frontend image..."
        
        # Set API URL for production build
        export REACT_APP_API_BASE_URL="http://127.0.0.1:8000"
        
        docker build --platform linux/amd64 -t aura-frontend aura-frontend/
        docker tag aura-frontend:latest "$ecr_uri/aura-frontend:latest"
        docker push "$ecr_uri/aura-frontend:latest"
        
        print_status "Frontend image built and pushed ✓"
    else
        # Backend or fullstack deployment
        print_status "Building Backend images..."
        
        # Build API Gateway
        print_status "  Building API Gateway..."
        docker build --platform linux/amd64 -f aura-backend/api-gateway/Dockerfile -t aura-api-gateway aura-backend/
        docker tag aura-api-gateway:latest "$ecr_uri/aura-api-gateway:latest"
        docker push "$ecr_uri/aura-api-gateway:latest"
        
        # Build Service Desk Host
        print_status "  Building Service Desk Host..."
        docker build --platform linux/amd64 -f aura-backend/service-desk-host/Dockerfile -t aura-service-desk-host aura-backend/
        docker tag aura-service-desk-host:latest "$ecr_uri/aura-service-desk-host:latest"
        docker push "$ecr_uri/aura-service-desk-host:latest"
        
        # Build Multi-Database
        print_status "  Building Multi-Database..."
        docker build --platform linux/amd64 -t aura-databases deploy/containers/multi-database/
        docker tag aura-databases:latest "$ecr_uri/aura-databases:latest"
        docker push "$ecr_uri/aura-databases:latest"
        
        # Build Frontend if fullstack
        if [[ "$deployment_type" == "fullstack" ]]; then
            print_status "  Building Frontend..."
            
            export REACT_APP_API_BASE_URL="http://127.0.0.1:8000"
            
            docker build --platform linux/amd64 -t aura-frontend aura-frontend/
            docker tag aura-frontend:latest "$ecr_uri/aura-frontend:latest"
            docker push "$ecr_uri/aura-frontend:latest"
        fi
    fi
    
    print_status "All required images built and pushed ✓"
}

# Function to create task definition
create_task_definition() {
    local environment=$1
    local deployment_type=$2
    
    print_status "Creating task definition for $deployment_type deployment..."
    
    # Select appropriate task definition template
    local task_def_template
    case "$deployment_type" in
        "frontend")
            task_def_template="deploy/aws/ecs/task-definition-frontend-only.json"
            ;;
        "fullstack")
            task_def_template="deploy/aws/ecs/task-definition-with-frontend.json"
            ;;
        *)
            task_def_template="deploy/aws/ecs/task-definition-final.json"
            ;;
    esac
    
    if [[ ! -f "$task_def_template" ]]; then
        print_error "Task definition template not found: $task_def_template"
        exit 1
    fi
    
    # Create updated task definition with current AWS account ID
    local updated_task_def="/tmp/task-definition-${environment}-$(date +%s).json"
    sed "s/753353727891/$AWS_ACCOUNT_ID/g" "$task_def_template" > "$updated_task_def"
    
    # Update family name
    local task_family="aura-app-${environment}"
    if [[ "$deployment_type" == "frontend" ]]; then
        task_family="aura-frontend-${environment}"
    fi
    
    # Update the family in the task definition
    jq --arg family "$task_family" '.family = $family' "$updated_task_def" > "${updated_task_def}.tmp"
    mv "${updated_task_def}.tmp" "$updated_task_def"
    
    echo "$updated_task_def"
}

# Function to create CloudWatch log group
create_log_group() {
    local environment=$1
    
    local log_group="/ecs/aura-app-${environment}"
    if ! aws logs describe-log-groups --log-group-name-prefix "$log_group" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$log_group"; then
        print_status "Creating CloudWatch log group: $log_group"
        aws logs create-log-group --log-group-name "$log_group" --region "$AWS_REGION"
        aws logs put-retention-policy --log-group-name "$log_group" --retention-in-days 7 --region "$AWS_REGION"
    else
        print_status "CloudWatch log group already exists: $log_group"
    fi
}

# Function to deploy to ECS
deploy_to_ecs() {
    local environment=$1
    local deployment_type=$2
    
    print_header "Deploying to ECS"
    
    # Create CloudWatch log group
    create_log_group "$environment"
    
    # Create task definition
    local task_def_file=$(create_task_definition "$environment" "$deployment_type")
    local task_family="aura-app-${environment}"
    local service_name="aura-app-service"
    
    if [[ "$deployment_type" == "frontend" ]]; then
        task_family="aura-frontend-${environment}"
        service_name="aura-frontend-service"
    fi
    
    # Register task definition
    print_status "Registering ECS task definition..."
    local task_def_arn=$(aws ecs register-task-definition \
        --cli-input-json file://"$task_def_file" \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text \
        --region "$AWS_REGION")
    
    print_status "Task definition registered: $task_def_arn"
    
    # Create ECS service
    print_status "Creating ECS service: $service_name"
    aws ecs create-service \
        --cluster "$CLUSTER_NAME" \
        --service-name "$service_name" \
        --task-definition "$task_family" \
        --desired-count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$PUBLIC_SUBNETS],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
        --region "$AWS_REGION" > /dev/null
    
    # Clean up temp file
    rm -f "$task_def_file"
    
    print_status "ECS service created successfully ✓"
}

# Function to wait for deployment and check health
wait_for_deployment() {
    local environment=$1
    local deployment_type=$2
    local health_timeout=${3:-300}
    
    print_header "Waiting for Deployment to Complete"
    
    local service_name="aura-app-service"
    if [[ "$deployment_type" == "frontend" ]]; then
        service_name="aura-frontend-service"
    fi
    
    print_status "Waiting for ECS service to stabilize (timeout: ${health_timeout}s)..."
    
    # Wait for service to stabilize with timeout
    local start_time=$(date +%s)
    local timeout_reached=false
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $health_timeout ]]; then
            timeout_reached=true
            break
        fi
        
        # Check service status
        local service_status=$(aws ecs describe-services \
            --cluster "$CLUSTER_NAME" \
            --services "$service_name" \
            --query 'services[0].deployments[0].status' \
            --output text \
            --region "$AWS_REGION" 2>/dev/null || echo "UNKNOWN")
        
        local running_count=$(aws ecs describe-services \
            --cluster "$CLUSTER_NAME" \
            --services "$service_name" \
            --query 'services[0].runningCount' \
            --output text \
            --region "$AWS_REGION" 2>/dev/null || echo "0")
        
        print_status "Service status: $service_status, Running tasks: $running_count (${elapsed}s elapsed)"
        
        if [[ "$service_status" == "PRIMARY" && "$running_count" -gt 0 ]]; then
            print_status "Service deployment completed ✓"
            break
        fi
        
        sleep 15
    done
    
    if [[ "$timeout_reached" == "true" ]]; then
        print_warning "Deployment timeout reached after ${health_timeout}s"
        print_status "Service may still be starting. Check AWS console for details."
        return 1
    fi
    
    return 0
}

# Function to get deployment info
get_deployment_info() {
    local environment=$1
    local deployment_type=$2
    
    print_header "Deployment Information"
    
    local service_name="aura-app-service"
    if [[ "$deployment_type" == "frontend" ]]; then
        service_name="aura-frontend-service"
    fi
    
    # Get task ARN
    local task_arns=$(aws ecs list-tasks \
        --cluster "$CLUSTER_NAME" \
        --service-name "$service_name" \
        --query 'taskArns[0]' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "")
    
    if [[ -n "$task_arns" && "$task_arns" != "None" && "$task_arns" != "null" ]]; then
        # Get public IP
        local eni_id=$(aws ecs describe-tasks \
            --cluster "$CLUSTER_NAME" \
            --tasks "$task_arns" \
            --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
            --output text \
            --region "$AWS_REGION" 2>/dev/null || echo "")
        
        if [[ -n "$eni_id" && "$eni_id" != "None" ]]; then
            local public_ip=$(aws ec2 describe-network-interfaces \
                --network-interface-ids "$eni_id" \
                --query 'NetworkInterfaces[0].Association.PublicIp' \
                --output text \
                --region "$AWS_REGION" 2>/dev/null || echo "")
            
            if [[ -n "$public_ip" && "$public_ip" != "None" ]]; then
                print_status "🎉 Application deployed successfully!"
                print_status ""
                print_status "Access your application at:"
                
                if [[ "$deployment_type" == "frontend" || "$deployment_type" == "fullstack" ]]; then
                    print_status "  🌐 Frontend UI: http://$public_ip:80"
                fi
                
                if [[ "$deployment_type" != "frontend" ]]; then
                    print_status "  🔌 API Gateway: http://$public_ip:8000"
                    print_status "  🎫 Service Desk: http://$public_ip:8001"
                    print_status "  📚 API Documentation: http://$public_ip:8000/docs"
                fi
                
                print_status ""
                print_status "Task ARN: $task_arns"
                print_status "Public IP: $public_ip"
                return 0
            fi
        fi
    fi
    
    print_warning "Could not retrieve deployment information"
    print_status "Check AWS ECS console for service details"
    return 1
}

# Function to perform health checks
perform_health_checks() {
    local environment=$1
    local deployment_type=$2
    local public_ip=$3
    
    print_header "Performing Health Checks"
    
    if [[ -z "$public_ip" ]]; then
        print_warning "No public IP available for health checks"
        return 1
    fi
    
    local health_check_passed=true
    
    # Check backend services
    if [[ "$deployment_type" != "frontend" ]]; then
        print_status "Checking API Gateway health..."
        if curl -s --max-time 10 "http://$public_ip:8000/health" > /dev/null; then
            print_status "  ✓ API Gateway is healthy"
        else
            print_error "  ✗ API Gateway health check failed"
            health_check_passed=false
        fi
        
        print_status "Checking Service Desk health..."
        if curl -s --max-time 10 "http://$public_ip:8001/health" > /dev/null; then
            print_status "  ✓ Service Desk is healthy"
        else
            print_error "  ✗ Service Desk health check failed"
            health_check_passed=false
        fi
    fi
    
    # Check frontend
    if [[ "$deployment_type" == "frontend" || "$deployment_type" == "fullstack" ]]; then
        print_status "Checking Frontend availability..."
        if curl -s --max-time 10 "http://$public_ip:80" > /dev/null; then
            print_status "  ✓ Frontend is accessible"
        else
            print_error "  ✗ Frontend health check failed"
            health_check_passed=false
        fi
    fi
    
    if [[ "$health_check_passed" == "true" ]]; then
        print_status "All health checks passed ✓"
        return 0
    else
        print_warning "Some health checks failed. Services may still be starting."
        return 1
    fi
}

# Main function
main() {
    local environment="dev"
    local deployment_type="backend"
    local cleanup_first=false
    local force=false
    local skip_build=false
    local health_timeout=300
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cleanup-first)
                cleanup_first=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --no-build)
                skip_build=true
                shift
                ;;
            --health-timeout)
                health_timeout="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                ;;
            dev|staging|prod)
                environment=$1
                shift
                ;;
            backend|frontend|fullstack)
                deployment_type=$1
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                ;;
        esac
    done
    
    # Set AWS region
    export AWS_DEFAULT_REGION=us-east-2
    export AWS_REGION=us-east-2
    
    print_header "Aura Team AWS Deployment"
    print_status "Environment: $environment"
    print_status "Deployment Type: $deployment_type"
    print_status "Cleanup First: $cleanup_first"
    print_status "Force: $force"
    print_status "Skip Build: $skip_build"
    print_status "Health Timeout: ${health_timeout}s"
    
    # Check prerequisites
    check_prerequisites
    
    # Load infrastructure
    load_infrastructure "$environment"
    
    # Cleanup existing services if requested
    if [[ "$cleanup_first" == "true" ]]; then
        cleanup_existing_services "$environment" "$force"
    fi
    
    # Create ECR repositories
    create_ecr_repositories
    
    # Build and push images
    build_and_push_images "$deployment_type" "$skip_build"
    
    # Deploy to ECS
    deploy_to_ecs "$environment" "$deployment_type"
    
    # Wait for deployment
    if wait_for_deployment "$environment" "$deployment_type" "$health_timeout"; then
        # Get deployment info
        get_deployment_info "$environment" "$deployment_type"
        
        # Perform health checks
        local service_name="aura-app-service"
        if [[ "$deployment_type" == "frontend" ]]; then
            service_name="aura-frontend-service"
        fi
        
        local task_arns=$(aws ecs list-tasks \
            --cluster "$CLUSTER_NAME" \
            --service-name "$service_name" \
            --query 'taskArns[0]' \
            --output text \
            --region "$AWS_REGION" 2>/dev/null || echo "")
        
        if [[ -n "$task_arns" && "$task_arns" != "None" ]]; then
            local eni_id=$(aws ecs describe-tasks \
                --cluster "$CLUSTER_NAME" \
                --tasks "$task_arns" \
                --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
                --output text \
                --region "$AWS_REGION" 2>/dev/null || echo "")
            
            if [[ -n "$eni_id" && "$eni_id" != "None" ]]; then
                local public_ip=$(aws ec2 describe-network-interfaces \
                    --network-interface-ids "$eni_id" \
                    --query 'NetworkInterfaces[0].Association.PublicIp' \
                    --output text \
                    --region "$AWS_REGION" 2>/dev/null || echo "")
                
                if [[ -n "$public_ip" && "$public_ip" != "None" ]]; then
                    sleep 30  # Give services time to fully start
                    perform_health_checks "$environment" "$deployment_type" "$public_ip"
                fi
            fi
        fi
        
        print_status "🎉 Deployment completed successfully!"
    else
        print_warning "Deployment may have issues. Check AWS ECS console for details."
    fi
}

# Run main function with all arguments
main "$@"
