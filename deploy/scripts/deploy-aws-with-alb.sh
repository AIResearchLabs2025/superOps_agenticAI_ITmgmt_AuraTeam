#!/bin/bash

# AWS ECS Deployment Script with Application Load Balancer
# This script addresses dynamic IP issues by using ALB for service discovery

set -e

# Configuration
ENVIRONMENT=${1:-dev}
DEPLOYMENT_TYPE=${2:-fullstack}
REGION="us-east-2"
ACCOUNT_ID="753353727891"
CLUSTER_NAME="aura-${ENVIRONMENT}-cluster"
SERVICE_NAME="aura-fullstack-service"
TASK_FAMILY="aura-fullstack-${ENVIRONMENT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Parse command line options
CLEANUP_FIRST=false
FORCE=false
NO_BUILD=false
HEALTH_TIMEOUT=300
CREATE_ALB=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --cleanup-first)
            CLEANUP_FIRST=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --no-build)
            NO_BUILD=true
            shift
            ;;
        --health-timeout)
            HEALTH_TIMEOUT="$2"
            shift 2
            ;;
        --create-alb)
            CREATE_ALB=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install it first."
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install it first."
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        error "jq is not installed. Please install it first."
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials are not configured or expired. Please run 'aws configure' or 'aws sso login'."
    fi
    
    log "✅ Prerequisites check passed"
}

# Function to load infrastructure information
load_infrastructure() {
    log "Loading infrastructure information..."
    
    INFRA_FILE="deploy/aws/infrastructure-${ENVIRONMENT}.json"
    if [[ ! -f "$INFRA_FILE" ]]; then
        error "Infrastructure file not found: $INFRA_FILE. Please run setup-aws-infrastructure.sh first."
    fi
    
    # Extract infrastructure details
    VPC_ID=$(jq -r '.vpc_id' "$INFRA_FILE")
    # Try subnet_ids first, then fall back to public_subnets
    SUBNET_IDS=$(jq -r '.subnet_ids[]?' "$INFRA_FILE" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    if [[ -z "$SUBNET_IDS" ]]; then
        SUBNET_IDS=$(jq -r '.public_subnets[]' "$INFRA_FILE" | tr '\n' ',' | sed 's/,$//')
    fi
    SECURITY_GROUP_ID=$(jq -r '.security_group_id' "$INFRA_FILE")
    
    if [[ "$VPC_ID" == "null" || "$SUBNET_IDS" == "null" || "$SECURITY_GROUP_ID" == "null" ]]; then
        error "Invalid infrastructure configuration in $INFRA_FILE"
    fi
    
    log "✅ Infrastructure loaded: VPC=$VPC_ID, Subnets=$SUBNET_IDS, SG=$SECURITY_GROUP_ID"
}

# Function to create Application Load Balancer
create_application_load_balancer() {
    if [[ "$CREATE_ALB" != "true" ]]; then
        log "Skipping ALB creation (use --create-alb to enable)"
        return
    fi
    
    log "Creating Application Load Balancer..."
    
    ALB_NAME="aura-${ENVIRONMENT}-alb"
    
    # Check if ALB already exists
    if aws elbv2 describe-load-balancers --names "$ALB_NAME" &> /dev/null; then
        log "ALB $ALB_NAME already exists"
        ALB_ARN=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --query 'LoadBalancers[0].LoadBalancerArn' --output text)
    else
        log "Creating new ALB: $ALB_NAME"
        
        # Create ALB
        ALB_ARN=$(aws elbv2 create-load-balancer \
            --name "$ALB_NAME" \
            --subnets $(echo $SUBNET_IDS | tr ',' ' ') \
            --security-groups "$SECURITY_GROUP_ID" \
            --scheme internet-facing \
            --type application \
            --ip-address-type ipv4 \
            --query 'LoadBalancers[0].LoadBalancerArn' \
            --output text)
        
        log "✅ ALB created: $ALB_ARN"
    fi
    
    # Create target groups
    create_target_groups
    
    # Create ALB listeners
    create_alb_listeners
}

# Function to create target groups
create_target_groups() {
    log "Creating target groups..."
    
    # API Gateway target group
    API_TG_NAME="aura-${ENVIRONMENT}-api-tg"
    if ! aws elbv2 describe-target-groups --names "$API_TG_NAME" &> /dev/null; then
        API_TG_ARN=$(aws elbv2 create-target-group \
            --name "$API_TG_NAME" \
            --protocol HTTP \
            --port 8000 \
            --vpc-id "$VPC_ID" \
            --target-type ip \
            --health-check-path "/health" \
            --health-check-interval-seconds 30 \
            --health-check-timeout-seconds 10 \
            --healthy-threshold-count 2 \
            --unhealthy-threshold-count 3 \
            --query 'TargetGroups[0].TargetGroupArn' \
            --output text)
        log "✅ API Gateway target group created: $API_TG_ARN"
    else
        API_TG_ARN=$(aws elbv2 describe-target-groups --names "$API_TG_NAME" --query 'TargetGroups[0].TargetGroupArn' --output text)
        log "API Gateway target group exists: $API_TG_ARN"
    fi
    
    # Service Desk target group
    SERVICE_TG_NAME="aura-${ENVIRONMENT}-service-tg"
    if ! aws elbv2 describe-target-groups --names "$SERVICE_TG_NAME" &> /dev/null; then
        SERVICE_TG_ARN=$(aws elbv2 create-target-group \
            --name "$SERVICE_TG_NAME" \
            --protocol HTTP \
            --port 8001 \
            --vpc-id "$VPC_ID" \
            --target-type ip \
            --health-check-path "/health" \
            --health-check-interval-seconds 30 \
            --health-check-timeout-seconds 10 \
            --healthy-threshold-count 2 \
            --unhealthy-threshold-count 3 \
            --query 'TargetGroups[0].TargetGroupArn' \
            --output text)
        log "✅ Service Desk target group created: $SERVICE_TG_ARN"
    else
        SERVICE_TG_ARN=$(aws elbv2 describe-target-groups --names "$SERVICE_TG_NAME" --query 'TargetGroups[0].TargetGroupArn' --output text)
        log "Service Desk target group exists: $SERVICE_TG_ARN"
    fi
}

# Function to create ALB listeners
create_alb_listeners() {
    log "Creating ALB listeners..."
    
    # Check if listener already exists
    if aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" | jq -e '.Listeners | length > 0' &> /dev/null; then
        log "ALB listeners already exist"
        return
    fi
    
    # Create listener with rules for path-based routing
    LISTENER_ARN=$(aws elbv2 create-listener \
        --load-balancer-arn "$ALB_ARN" \
        --protocol HTTP \
        --port 80 \
        --default-actions Type=forward,TargetGroupArn="$API_TG_ARN" \
        --query 'Listeners[0].ListenerArn' \
        --output text)
    
    # Create rule for service desk paths
    aws elbv2 create-rule \
        --listener-arn "$LISTENER_ARN" \
        --priority 100 \
        --conditions Field=path-pattern,Values="/api/v1/kb/*","/api/v1/chatbot/*" \
        --actions Type=forward,TargetGroupArn="$SERVICE_TG_ARN" > /dev/null
    
    log "✅ ALB listeners created with path-based routing"
}

# Function to cleanup existing services
cleanup_services() {
    if [[ "$CLEANUP_FIRST" != "true" ]]; then
        return
    fi
    
    log "Cleaning up existing services..."
    
    # Check if service exists
    if aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --query 'services[0].serviceName' --output text 2>/dev/null | grep -q "$SERVICE_NAME"; then
        log "Scaling down service to 0 tasks..."
        aws ecs update-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" --desired-count 0 > /dev/null
        
        log "Waiting for tasks to stop..."
        aws ecs wait services-stable --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME"
        
        log "Deleting service..."
        aws ecs delete-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" > /dev/null
        
        log "Waiting for service deletion..."
        sleep 30
    fi
    
    # Force stop any remaining tasks
    TASK_ARNS=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --query 'taskArns[]' --output text)
    if [[ -n "$TASK_ARNS" && "$TASK_ARNS" != "None" ]]; then
        log "Force stopping remaining tasks..."
        for task_arn in $TASK_ARNS; do
            aws ecs stop-task --cluster "$CLUSTER_NAME" --task "$task_arn" > /dev/null || true
        done
    fi
    
    log "✅ Cleanup completed"
}

# Function to create ECR repositories
create_ecr_repositories() {
    log "Creating ECR repositories..."
    
    REPOSITORIES=("aura-api-gateway" "aura-service-desk-host" "aura-databases" "aura-frontend")
    
    for repo in "${REPOSITORIES[@]}"; do
        if ! aws ecr describe-repositories --repository-names "$repo" &> /dev/null; then
            log "Creating ECR repository: $repo"
            aws ecr create-repository --repository-name "$repo" > /dev/null
        else
            log "ECR repository exists: $repo"
        fi
    done
    
    log "✅ ECR repositories ready"
}

# Function to build and push Docker images
build_and_push_images() {
    if [[ "$NO_BUILD" == "true" ]]; then
        log "Skipping image build (--no-build specified)"
        return
    fi
    
    log "Building and pushing Docker images..."
    
    # Login to ECR
    aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
    
    # Build and push API Gateway
    if [[ "$DEPLOYMENT_TYPE" == "backend" || "$DEPLOYMENT_TYPE" == "fullstack" ]]; then
        log "Building API Gateway image..."
        docker build --platform linux/amd64 -t "aura-api-gateway:latest" -f aura-backend/api-gateway/Dockerfile aura-backend/
        docker tag "aura-api-gateway:latest" "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/aura-api-gateway:latest"
        docker push "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/aura-api-gateway:latest"
        
        log "Building Service Desk image..."
        docker build --platform linux/amd64 -t "aura-service-desk-host:latest" -f aura-backend/service-desk-host/Dockerfile aura-backend/
        docker tag "aura-service-desk-host:latest" "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/aura-service-desk-host:latest"
        docker push "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/aura-service-desk-host:latest"
        
        log "Building Databases image..."
        docker build --platform linux/amd64 -t "aura-databases:latest" -f deploy/containers/multi-database/Dockerfile deploy/containers/multi-database/
        docker tag "aura-databases:latest" "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/aura-databases:latest"
        docker push "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/aura-databases:latest"
    fi
    
    # Build and push Frontend
    if [[ "$DEPLOYMENT_TYPE" == "frontend" || "$DEPLOYMENT_TYPE" == "fullstack" ]]; then
        log "Building Frontend image..."
        
        # Get ALB DNS name for frontend configuration
        if [[ "$CREATE_ALB" == "true" ]]; then
            ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --query 'LoadBalancers[0].DNSName' --output text)
            export REACT_APP_API_BASE_URL="http://${ALB_DNS}"
        fi
        
        docker build --platform linux/amd64 -t "aura-frontend:latest" aura-frontend/
        docker tag "aura-frontend:latest" "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/aura-frontend:latest"
        docker push "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/aura-frontend:latest"
    fi
    
    log "✅ Images built and pushed successfully"
}

# Function to create CloudWatch log groups
create_log_groups() {
    log "Creating CloudWatch log groups..."
    
    LOG_GROUP="/ecs/aura-app-${ENVIRONMENT}"
    
    if ! aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" | jq -e ".logGroups[] | select(.logGroupName == \"$LOG_GROUP\")" > /dev/null; then
        aws logs create-log-group --log-group-name "$LOG_GROUP"
        aws logs put-retention-policy --log-group-name "$LOG_GROUP" --retention-in-days 7
        log "✅ Log group created: $LOG_GROUP"
    else
        log "Log group exists: $LOG_GROUP"
    fi
}

# Function to register task definition
register_task_definition() {
    log "Registering ECS task definition..."
    
    # Use the service-connect task definition for better networking
    TASK_DEF_FILE="deploy/aws/ecs/task-definition-service-connect.json"
    
    if [[ ! -f "$TASK_DEF_FILE" ]]; then
        error "Task definition file not found: $TASK_DEF_FILE"
    fi
    
    # Register the task definition
    TASK_DEF_ARN=$(aws ecs register-task-definition --cli-input-json file://"$TASK_DEF_FILE" --query 'taskDefinition.taskDefinitionArn' --output text)
    
    log "✅ Task definition registered: $TASK_DEF_ARN"
}

# Function to create ECS service
create_ecs_service() {
    log "Creating ECS service..."
    
    # Prepare load balancer configuration if ALB is created
    LOAD_BALANCER_CONFIG=""
    if [[ "$CREATE_ALB" == "true" ]]; then
        LOAD_BALANCER_CONFIG="--load-balancers targetGroupArn=$API_TG_ARN,containerName=api-gateway,containerPort=8000 targetGroupArn=$SERVICE_TG_ARN,containerName=service-desk-host,containerPort=8001"
    fi
    
    # Create service
    SERVICE_ARN=$(aws ecs create-service \
        --cluster "$CLUSTER_NAME" \
        --service-name "$SERVICE_NAME" \
        --task-definition "$TASK_DEF_ARN" \
        --desired-count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
        $LOAD_BALANCER_CONFIG \
        --query 'service.serviceArn' \
        --output text)
    
    log "✅ ECS service created: $SERVICE_ARN"
}

# Function to wait for service stability and perform health checks
wait_for_service_health() {
    log "Waiting for service to become stable..."
    
    # Wait for service to be stable
    aws ecs wait services-stable --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME"
    
    log "Service is stable. Performing health checks..."
    
    # Get task details for health checking
    TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --service-name "$SERVICE_NAME" --query 'taskArns[0]' --output text)
    
    if [[ "$TASK_ARN" == "None" || -z "$TASK_ARN" ]]; then
        error "No tasks found for service $SERVICE_NAME"
    fi
    
    # Get task details including network interface
    TASK_DETAILS=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN")
    ENI_ID=$(echo "$TASK_DETAILS" | jq -r '.tasks[0].attachments[0].details[] | select(.name=="networkInterfaceId") | .value')
    
    if [[ "$ENI_ID" != "null" && -n "$ENI_ID" ]]; then
        PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI_ID" --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
        
        if [[ "$PUBLIC_IP" != "None" && -n "$PUBLIC_IP" ]]; then
            log "Task public IP: $PUBLIC_IP"
            
            # Health check endpoints
            ENDPOINTS=(
                "http://$PUBLIC_IP:8000/health"
                "http://$PUBLIC_IP:8001/health"
            )
            
            for endpoint in "${ENDPOINTS[@]}"; do
                log "Checking health endpoint: $endpoint"
                
                for i in {1..10}; do
                    if curl -f -s --connect-timeout 10 "$endpoint" > /dev/null; then
                        log "✅ Health check passed: $endpoint"
                        break
                    else
                        if [[ $i -eq 10 ]]; then
                            warn "Health check failed after 10 attempts: $endpoint"
                        else
                            log "Health check attempt $i/10 failed, retrying in 30s..."
                            sleep 30
                        fi
                    fi
                done
            done
        else
            warn "Could not determine public IP for health checks"
        fi
    else
        warn "Could not determine network interface for health checks"
    fi
}

# Function to display deployment summary
display_summary() {
    log "Deployment Summary"
    echo "=================="
    echo "Environment: $ENVIRONMENT"
    echo "Deployment Type: $DEPLOYMENT_TYPE"
    echo "Cluster: $CLUSTER_NAME"
    echo "Service: $SERVICE_NAME"
    echo "Task Definition: $TASK_DEF_ARN"
    
    # Get service details
    SERVICE_DETAILS=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME")
    RUNNING_COUNT=$(echo "$SERVICE_DETAILS" | jq -r '.services[0].runningCount')
    DESIRED_COUNT=$(echo "$SERVICE_DETAILS" | jq -r '.services[0].desiredCount')
    
    echo "Running Tasks: $RUNNING_COUNT/$DESIRED_COUNT"
    
    # Display access URLs
    if [[ -n "$PUBLIC_IP" ]]; then
        echo ""
        echo "Access URLs:"
        echo "  API Gateway: http://$PUBLIC_IP:8000"
        echo "  Service Desk: http://$PUBLIC_IP:8001"
        echo "  API Documentation: http://$PUBLIC_IP:8000/docs"
        
        if [[ "$DEPLOYMENT_TYPE" == "fullstack" ]]; then
            echo "  Frontend: http://$PUBLIC_IP:80"
        fi
    fi
    
    # Display ALB URLs if created
    if [[ "$CREATE_ALB" == "true" && -n "$ALB_DNS" ]]; then
        echo ""
        echo "Load Balancer URLs:"
        echo "  ALB Endpoint: http://$ALB_DNS"
        echo "  API Gateway (via ALB): http://$ALB_DNS/api/v1/"
        echo "  Knowledge Base (via ALB): http://$ALB_DNS/api/v1/kb/"
    fi
    
    echo ""
    echo "Monitoring:"
    echo "  CloudWatch Logs: /ecs/aura-app-$ENVIRONMENT"
    echo "  ECS Console: https://console.aws.amazon.com/ecs/home?region=$REGION#/clusters/$CLUSTER_NAME/services"
    
    log "✅ Deployment completed successfully!"
}

# Main execution
main() {
    log "Starting AWS ECS deployment with ALB support..."
    log "Environment: $ENVIRONMENT, Type: $DEPLOYMENT_TYPE"
    
    check_prerequisites
    load_infrastructure
    
    if [[ "$FORCE" != "true" ]]; then
        echo "This will deploy the Aura application to AWS ECS."
        echo "Environment: $ENVIRONMENT"
        echo "Deployment Type: $DEPLOYMENT_TYPE"
        echo "Cleanup First: $CLEANUP_FIRST"
        echo "Create ALB: $CREATE_ALB"
        echo ""
        read -p "Do you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Deployment cancelled by user"
            exit 0
        fi
    fi
    
    cleanup_services
    create_application_load_balancer
    create_ecr_repositories
    build_and_push_images
    create_log_groups
    register_task_definition
    create_ecs_service
    wait_for_service_health
    display_summary
}

# Run main function
main "$@"
