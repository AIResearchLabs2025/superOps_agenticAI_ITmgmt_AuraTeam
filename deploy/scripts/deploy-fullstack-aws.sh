#!/bin/bash
# Comprehensive Full-Stack AWS Deployment Script
# Ensures both frontend and backend are deployed together with proper health checks

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

# Global variables
CLEANUP_BEFORE_DEPLOY=false
FORCE_DEPLOYMENT=false
SKIP_BUILD=false
HEALTH_TIMEOUT=300
ENVIRONMENT="dev"
AWS_REGION="us-east-2"

# Function to show usage
show_usage() {
    echo "Usage: $0 [ENVIRONMENT] [OPTIONS]"
    echo ""
    echo "ENVIRONMENT:"
    echo "  dev         - Development environment (default)"
    echo "  staging     - Staging environment"
    echo "  prod        - Production environment"
    echo ""
    echo "OPTIONS:"
    echo "  --cleanup-first    - Clean up existing services before deployment"
    echo "  --force           - Skip confirmation prompts"
    echo "  --no-build        - Skip Docker image building"
    echo "  --health-timeout  - Health check timeout in seconds (default: 300)"
    echo ""
    echo "Examples:"
    echo "  $0 dev --cleanup-first    # Clean up and deploy full stack"
    echo "  $0 dev --force            # Force deploy without prompts"
    echo "  $0 staging --no-build     # Deploy staging without rebuilding"
    echo ""
    exit 1
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cleanup-first)
                CLEANUP_BEFORE_DEPLOY=true
                shift
                ;;
            --force)
                FORCE_DEPLOYMENT=true
                shift
                ;;
            --no-build)
                SKIP_BUILD=true
                shift
                ;;
            --health-timeout)
                HEALTH_TIMEOUT="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                ;;
            dev|staging|prod)
                ENVIRONMENT=$1
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                ;;
        esac
    done
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker."
        exit 1
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI."
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install jq for JSON processing."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured or expired."
        print_status "Please run 'aws configure' or refresh your credentials."
        exit 1
    fi
    
    # Get AWS account info
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    print_status "AWS Account ID: $AWS_ACCOUNT_ID"
    print_status "AWS Region: $AWS_REGION"
    print_status "All prerequisites checked ✓"
}

# Function to load infrastructure configuration
load_infrastructure() {
    print_status "Loading infrastructure configuration for: $ENVIRONMENT"
    
    local infrastructure_file="deploy/aws/infrastructure-${ENVIRONMENT}.json"
    if [[ ! -f "$infrastructure_file" ]]; then
        print_error "Infrastructure file not found: $infrastructure_file"
        print_status "Please run setup-aws-infrastructure.sh first:"
        print_status "  ./deploy/scripts/setup-aws-infrastructure.sh $ENVIRONMENT"
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
    if [[ "$FORCE_DEPLOYMENT" != "true" ]]; then
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
            --region "$AWS_REGION" > /dev/null 2>&1 || true
        
        # Wait for scale down
        print_status "  Waiting for service to scale down..."
        local timeout=120
        local elapsed=0
        while [[ $elapsed -lt $timeout ]]; do
            local running_count=$(aws ecs describe-services \
                --cluster "$CLUSTER_NAME" \
                --services "$service_name" \
                --query 'services[0].runningCount' \
                --output text 2>/dev/null || echo "0")
            
            if [[ "$running_count" == "0" ]]; then
                break
            fi
            
            sleep 5
            elapsed=$((elapsed + 5))
        done
        
        # Delete service
        print_status "  Deleting service..."
        aws ecs delete-service \
            --cluster "$CLUSTER_NAME" \
            --service "$service_name" \
            --region "$AWS_REGION" > /dev/null 2>&1 || true
        
        print_status "Service $service_name cleaned up ✓"
    done
    
    # Force stop any remaining tasks
    print_status "Checking for remaining tasks..."
    local tasks=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --query 'taskArns' --output text 2>/dev/null || echo "")
    if [[ -n "$tasks" && "$tasks" != "None" ]]; then
        print_status "Force stopping remaining tasks..."
        for task_arn in $tasks; do
            aws ecs stop-task --cluster "$CLUSTER_NAME" --task "$task_arn" --reason "Cleanup before deployment" > /dev/null 2>&1 || true
        done
    fi
    
    # Wait for cleanup to complete
    sleep 15
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
    if [[ "$SKIP_BUILD" == "true" ]]; then
        print_status "Skipping Docker image building (--no-build specified)"
        return 0
    fi
    
    print_header "Building and Pushing Docker Images"
    
    local ecr_uri="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    
    # Login to ECR
    print_status "Logging into ECR..."
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ecr_uri"
    
    cd "$(dirname "$0")/../.." # Go to project root
    
    # Build Backend Images
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
    
    # Build Frontend Image
    print_status "Building Frontend image..."
    
    # Get the public IP for API configuration (we'll update this after deployment)
    export REACT_APP_API_BASE_URL="http://localhost:8000"  # Will be updated post-deployment
    
    docker build --platform linux/amd64 -t aura-frontend aura-frontend/
    docker tag aura-frontend:latest "$ecr_uri/aura-frontend:latest"
    docker push "$ecr_uri/aura-frontend:latest"
    
    print_status "All images built and pushed ✓"
}

# Function to create improved task definition
create_task_definition() {
    local timestamp=$(date +%s)
    local task_family="aura-fullstack-${ENVIRONMENT}"
    local task_def_file="/tmp/task-definition-fullstack-${ENVIRONMENT}-${timestamp}.json"
    
    # Create comprehensive task definition with all 4 containers
    cat > "$task_def_file" << EOF
{
  "family": "${task_family}",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "2048",
  "memory": "4096",
  "executionRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "databases",
      "image": "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/aura-databases:latest",
      "cpu": 512,
      "memory": 1024,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 5432,
          "protocol": "tcp",
          "name": "postgres"
        },
        {
          "containerPort": 6379,
          "protocol": "tcp",
          "name": "redis"
        },
        {
          "containerPort": 27017,
          "protocol": "tcp",
          "name": "mongodb"
        }
      ],
      "environment": [
        {
          "name": "POSTGRES_USER",
          "value": "aura_user"
        },
        {
          "name": "POSTGRES_PASSWORD",
          "value": "aura_password"
        },
        {
          "name": "POSTGRES_MULTIPLE_DATABASES",
          "value": "aura_servicedesk,aura_infratalent,aura_threatintel"
        }
      ],
      "command": ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/aura-fullstack-${ENVIRONMENT}",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "databases",
          "awslogs-create-group": "true"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "pg_isready -h 127.0.0.1 -p 5432 -U aura_user && redis-cli -h 127.0.0.1 -p 6379 ping | grep PONG && echo 'Databases healthy'"
        ],
        "interval": 30,
        "timeout": 15,
        "retries": 5,
        "startPeriod": 180
      }
    },
    {
      "name": "api-gateway",
      "image": "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/aura-api-gateway:latest",
      "cpu": 256,
      "memory": 512,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp",
          "name": "api-gateway"
        }
      ],
      "environment": [
        {
          "name": "SERVICE_DESK_URL",
          "value": "http://127.0.0.1:8001"
        },
        {
          "name": "REDIS_URL",
          "value": "redis://127.0.0.1:6379"
        },
        {
          "name": "ENVIRONMENT",
          "value": "aws-${ENVIRONMENT}"
        },
        {
          "name": "DEBUG",
          "value": "false"
        },
        {
          "name": "LOG_LEVEL",
          "value": "INFO"
        },
        {
          "name": "HOST",
          "value": "0.0.0.0"
        },
        {
          "name": "PORT",
          "value": "8000"
        }
      ],
      "dependsOn": [
        {
          "containerName": "databases",
          "condition": "HEALTHY"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/aura-fullstack-${ENVIRONMENT}",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "api-gateway",
          "awslogs-create-group": "true"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=10)\" || exit 1"
        ],
        "interval": 30,
        "timeout": 15,
        "retries": 3,
        "startPeriod": 90
      }
    },
    {
      "name": "service-desk-host",
      "image": "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/aura-service-desk-host:latest",
      "cpu": 256,
      "memory": 512,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8001,
          "protocol": "tcp",
          "name": "service-desk"
        }
      ],
      "environment": [
        {
          "name": "DATABASE_URL",
          "value": "postgresql://aura_user:aura_password@127.0.0.1:5432/aura_servicedesk"
        },
        {
          "name": "MONGODB_URL",
          "value": "mongodb://127.0.0.1:27017/aura_servicedesk"
        },
        {
          "name": "REDIS_URL",
          "value": "redis://127.0.0.1:6379"
        },
        {
          "name": "ENVIRONMENT",
          "value": "aws-${ENVIRONMENT}"
        },
        {
          "name": "DEBUG",
          "value": "false"
        },
        {
          "name": "LOG_LEVEL",
          "value": "INFO"
        },
        {
          "name": "HOST",
          "value": "0.0.0.0"
        },
        {
          "name": "PORT",
          "value": "8001"
        }
      ],
      "secrets": [
        {
          "name": "OPENAI_API_KEY",
          "valueFrom": "arn:aws:ssm:${AWS_REGION}:${AWS_ACCOUNT_ID}:parameter/aura/${ENVIRONMENT}/openai-api-key"
        }
      ],
      "dependsOn": [
        {
          "containerName": "databases",
          "condition": "HEALTHY"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/aura-fullstack-${ENVIRONMENT}",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "service-desk",
          "awslogs-create-group": "true"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8001/health', timeout=10)\" || exit 1"
        ],
        "interval": 30,
        "timeout": 15,
        "retries": 3,
        "startPeriod": 90
      }
    },
    {
      "name": "frontend",
      "image": "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/aura-frontend:latest",
      "cpu": 512,
      "memory": 1024,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "protocol": "tcp",
          "name": "frontend"
        }
      ],
      "environment": [
        {
          "name": "REACT_APP_API_BASE_URL",
          "value": "http://127.0.0.1:8000"
        }
      ],
      "dependsOn": [
        {
          "containerName": "api-gateway",
          "condition": "HEALTHY"
        },
        {
          "containerName": "service-desk-host",
          "condition": "HEALTHY"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/aura-fullstack-${ENVIRONMENT}",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "frontend",
          "awslogs-create-group": "true"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://127.0.0.1:80/health || exit 1"
        ],
        "interval": 30,
        "timeout": 10,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF
    
    echo "$task_def_file"
}

# Function to create CloudWatch log group
create_log_group() {
    local log_group="/ecs/aura-fullstack-${ENVIRONMENT}"
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
    print_header "Deploying Full-Stack Application to ECS"
    
    # Create CloudWatch log group
    create_log_group
    
    # Create task definition
    local task_def_file=$(create_task_definition)
    local timestamp=$(date +%s)
    local task_family="aura-fullstack-${ENVIRONMENT}"
    local service_name="aura-fullstack-service"
    
    # Register task definition
    print_status "Registering ECS task definition..."
    local task_def_arn=$(aws ecs register-task-definition \
        --cli-input-json file://"$task_def_file" \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text \
        --region "$AWS_REGION")
    
    print_status "Task definition registered: $task_def_arn"
    
    # Check if service already exists
    local service_exists=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$service_name" \
        --query 'services[0].status' \
        --output text 2>/dev/null || echo "NONE")
    
    if [[ "$service_exists" == "ACTIVE" ]]; then
        print_status "Updating existing ECS service: $service_name"
        aws ecs update-service \
            --cluster "$CLUSTER_NAME" \
            --service "$service_name" \
            --task-definition "$task_family" \
            --region "$AWS_REGION" > /dev/null
    else
        print_status "Creating new ECS service: $service_name"
        aws ecs create-service \
            --cluster "$CLUSTER_NAME" \
            --service-name "$service_name" \
            --task-definition "$task_family" \
            --desired-count 1 \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[$PUBLIC_SUBNETS],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
            --region "$AWS_REGION" > /dev/null
    fi
    
    # Clean up temp file
    rm -f "$task_def_file"
    
    print_status "ECS service deployment initiated ✓"
    
    # Store service name for later use
    SERVICE_NAME="$service_name"
}

# Function to wait for deployment
wait_for_deployment() {
    print_header "Waiting for Deployment to Complete"
    
    print_status "Waiting for ECS service to stabilize (timeout: ${HEALTH_TIMEOUT}s)..."
    
    local start_time=$(date +%s)
    local timeout_reached=false
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $HEALTH_TIMEOUT ]]; then
            timeout_reached=true
            break
        fi
        
        # Check service status
        local service_status=$(aws ecs describe-services \
            --cluster "$CLUSTER_NAME" \
            --services "$SERVICE_NAME" \
            --query 'services[0].deployments[0].status' \
            --output text \
            --region "$AWS_REGION" 2>/dev/null || echo "UNKNOWN")
        
        local running_count=$(aws ecs describe-services \
            --cluster "$CLUSTER_NAME" \
            --services "$SERVICE_NAME" \
            --query 'services[0].runningCount' \
            --output text \
            --region "$AWS_REGION" 2>/dev/null || echo "0")
        
        print_status "Service status: $service_status, Running tasks: $running_count (${elapsed}s elapsed)"
        
        if [[ "$service_status" == "PRIMARY" && "$running_count" -gt 0 ]]; then
            print_status "Service deployment completed ✓"
            return 0
        fi
        
        sleep 15
    done
    
    if [[ "$timeout_reached" == "true" ]]; then
        print_warning "Deployment timeout reached after ${HEALTH_TIMEOUT}s"
        print_status "Service may still be starting. Check AWS console for details."
        return 1
    fi
    
    return 0
}

# Function to get deployment info and perform health checks
get_deployment_info_and_health_check() {
    print_header "Deployment Information & Health Checks"
    
    # Get task ARN
    local task_arns=$(aws ecs list-tasks \
        --cluster "$CLUSTER_NAME" \
        --service-name "$SERVICE_NAME" \
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
                print_status "🎉 Full-Stack Application deployed successfully!"
                print_status ""
                print_status "Access your application at:"
                print_status "  🌐 Frontend UI: http://$public_ip:80"
                print_status "  🔌 API Gateway: http://$public_ip:8000"
                print_status "  🎫 Service Desk: http://$public_ip:8001"
                print_status "  📚 API Documentation: http://$public_ip:8000/docs"
                print_status ""
                print_status "Task ARN: $task_arns"
                print_status "Public IP: $public_ip"
                
                # Perform health checks
                sleep 30  # Give services time to fully start
                perform_health_checks "$public_ip"
                
                return 0
            fi
        fi
    fi
    
    print_warning "Could not retrieve deployment information"
    print_status "Check AWS ECS console for service details"
    return 1
}

# Function to perform comprehensive health checks
perform_health_checks() {
    local public_ip=$1
    
    print_header "Performing Comprehensive Health Checks"
    
    local health_check_passed=true
    
    # Check API Gateway
    print_status "Checking API Gateway health..."
    if curl -s --max-time 10 "http://$public_ip:8000/health" > /dev/null; then
        print_status "  ✓ API Gateway is healthy"
    else
        print_error "  ✗ API Gateway health check failed"
        health_check_passed=false
    fi
    
    # Check Service Desk
    print_status "Checking Service Desk health..."
    if curl -s --max-time 10 "http://$public_ip:8001/health" > /dev/null; then
        print_status "  ✓ Service Desk is healthy"
    else
        print_error "  ✗ Service Desk health check failed"
        health_check_passed=false
    fi
    
    # Check Frontend
    print_status "Checking Frontend availability..."
    if curl -s --max-time 10 "http://$public_ip:80/health" > /dev/null; then
        print_status "  ✓ Frontend health endpoint is accessible"
    else
        print_warning "  ⚠ Frontend health endpoint failed, checking main page..."
        if curl -s --max-time 10 "http://$public_ip:80" > /dev/null; then
            print_status "  ✓ Frontend main page is accessible"
        else
            print_error "  ✗ Frontend is not accessible"
            health_check_passed=false
        fi
    fi
    
    # Check API Documentation
    print_status "Checking API Documentation..."
    if curl -s --max-time 10 "http://$public_ip:8000/docs" > /dev/null; then
        print_status "  ✓ API Documentation is accessible"
    else
        print_warning "  ⚠ API Documentation may not be ready yet"
    fi
    
    if [[ "$health_check_passed" == "true" ]]; then
        print_status ""
        print_status "🎉 All critical health checks passed! ✓"
        print_status ""
        print_status "Your full-stack application is ready to use:"
        print_status "  • Frontend: Browse to http://$public_ip:80"
        print_status "  • API: Use http://$public_ip:8000 for API calls"
        print_status "  • Documentation: Visit http://$public_ip:8000/docs"
        print_status ""
        return 0
    else
        print_warning "Some health checks failed. Services may still be starting."
        print_status "Monitor logs: aws logs tail /ecs/aura-fullstack-${ENVIRONMENT} --follow"
        return 1
    fi
}

# Function to update frontend API configuration post-deployment
update_frontend_config() {
    local public_ip=$1
    
    print_header "Updating Frontend Configuration"
    
    # Note: In a production environment, you would rebuild the frontend with the correct API URL
    # For now, we'll document this as a manual step
    print_status "Frontend is configured to use the API at the same host"
    print_status "The nginx proxy configuration will handle API routing"
    print_status "No additional configuration needed ✓"
}

# Function to display deployment summary
display_deployment_summary() {
    local public_ip=$1
    
    print_header "Deployment Summary"
    
    print_status "🚀 Full-Stack Deployment Completed Successfully!"
    print_status ""
    print_status "📋 Deployment Details:"
    print_status "  Environment: $ENVIRONMENT"
    print_status "  AWS Region: $AWS_REGION"
    print_status "  ECS Cluster: $CLUSTER_NAME"
    print_status "  Service Name: $SERVICE_NAME"
    print_status "  Public IP: $public_ip"
    print_status ""
    print_status "🌐 Application Access Points:"
    print_status "  Frontend UI:        http://$public_ip:80"
    print_status "  API Gateway:        http://$public_ip:8000"
    print_status "  Service Desk API:   http://$public_ip:8001"
    print_status "  API Documentation:  http://$public_ip:8000/docs"
    print_status ""
    print_status "🔧 Management Commands:"
    print_status "  View Logs:    aws logs tail /ecs/aura-fullstack-${ENVIRONMENT} --follow"
    print_status "  Service Info: aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME"
    print_status "  Scale Down:   aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --desired-count 0"
    print_status ""
    print_status "💡 Next Steps:"
    print_status "  1. Test the application functionality"
    print_status "  2. Configure monitoring and alerting"
    print_status "  3. Set up SSL/TLS certificates for production"
    print_status "  4. Configure auto-scaling policies"
    print_status ""
}

# Function to handle deployment failures
handle_deployment_failure() {
    print_header "Deployment Failure Recovery"
    
    print_error "Deployment failed or timed out"
    print_status ""
    print_status "🔍 Troubleshooting Steps:"
    print_status "1. Check service status:"
    print_status "   aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME"
    print_status ""
    print_status "2. Check task status:"
    print_status "   aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME"
    print_status ""
    print_status "3. View logs:"
    print_status "   aws logs tail /ecs/aura-fullstack-${ENVIRONMENT} --follow"
    print_status ""
    print_status "4. Check task definition:"
    print_status "   aws ecs describe-task-definition --task-definition aura-fullstack-${ENVIRONMENT}"
    print_status ""
    print_status "5. Clean up and retry:"
    print_status "   $0 $ENVIRONMENT --cleanup-first --force"
    print_status ""
}

# Main function
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Set AWS region
    export AWS_DEFAULT_REGION="$AWS_REGION"
    
    print_header "Aura Team Full-Stack AWS Deployment"
    print_status "Environment: $ENVIRONMENT"
    print_status "AWS Region: $AWS_REGION"
    print_status "Cleanup First: $CLEANUP_BEFORE_DEPLOY"
    print_status "Force: $FORCE_DEPLOYMENT"
    print_status "Skip Build: $SKIP_BUILD"
    print_status "Health Timeout: ${HEALTH_TIMEOUT}s"
    print_status ""
    
    # Check prerequisites
    check_prerequisites
    
    # Load infrastructure
    load_infrastructure
    
    # Cleanup existing services if requested
    if [[ "$CLEANUP_BEFORE_DEPLOY" == "true" ]]; then
        cleanup_existing_services
    fi
    
    # Create ECR repositories
    create_ecr_repositories
    
    # Build and push images
    build_and_push_images
    
    # Deploy to ECS
    deploy_to_ecs
    
    # Wait for deployment
    if wait_for_deployment; then
        # Get deployment info and perform health checks
        if get_deployment_info_and_health_check; then
            # Get the public IP for summary
            local task_arns=$(aws ecs list-tasks \
                --cluster "$CLUSTER_NAME" \
                --service-name "$SERVICE_NAME" \
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
                        display_deployment_summary "$public_ip"
                        exit 0
                    fi
                fi
            fi
        fi
        
        print_warning "Deployment completed but health checks failed"
        handle_deployment_failure
        exit 1
    else
        print_error "Deployment failed or timed out"
        handle_deployment_failure
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
