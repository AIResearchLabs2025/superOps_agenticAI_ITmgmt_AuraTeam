#!/bin/bash
# Service Monitoring Script for AWS ECS Deployment
# Monitors service health and prevents continuous restart loops

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
ENVIRONMENT="dev"
AWS_REGION="us-east-2"
MONITOR_DURATION=300  # 5 minutes default
CHECK_INTERVAL=30     # 30 seconds between checks
RESTART_THRESHOLD=3   # Max restarts before alerting

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
    echo "  --duration SECONDS    - Monitor duration in seconds (default: 300)"
    echo "  --interval SECONDS    - Check interval in seconds (default: 30)"
    echo "  --threshold COUNT     - Restart threshold before alert (default: 3)"
    echo "  --continuous         - Monitor continuously (until Ctrl+C)"
    echo ""
    echo "Examples:"
    echo "  $0 dev                           # Monitor dev for 5 minutes"
    echo "  $0 dev --duration 600            # Monitor dev for 10 minutes"
    echo "  $0 prod --continuous             # Monitor prod continuously"
    echo ""
    exit 1
}

# Function to parse command line arguments
parse_arguments() {
    local continuous=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --duration)
                MONITOR_DURATION="$2"
                shift 2
                ;;
            --interval)
                CHECK_INTERVAL="$2"
                shift 2
                ;;
            --threshold)
                RESTART_THRESHOLD="$2"
                shift 2
                ;;
            --continuous)
                continuous=true
                MONITOR_DURATION=999999999  # Very large number for continuous monitoring
                shift
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
    
    if [[ "$continuous" == "true" ]]; then
        print_status "Continuous monitoring enabled (press Ctrl+C to stop)"
    fi
}

# Function to check prerequisites
check_prerequisites() {
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI."
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
}

# Function to load infrastructure configuration
load_infrastructure() {
    local infrastructure_file="deploy/aws/infrastructure-${ENVIRONMENT}.json"
    if [[ ! -f "$infrastructure_file" ]]; then
        print_error "Infrastructure file not found: $infrastructure_file"
        exit 1
    fi
    
    # Load infrastructure variables
    CLUSTER_NAME=$(jq -r '.ecs_cluster' "$infrastructure_file")
    
    print_status "ECS Cluster: $CLUSTER_NAME"
}

# Function to get service information
get_service_info() {
    local service_name=$1
    
    local service_info=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$service_name" \
        --query 'services[0]' \
        --output json 2>/dev/null || echo "{}")
    
    if [[ "$service_info" == "{}" || "$service_info" == "null" ]]; then
        echo "NOT_FOUND"
        return 1
    fi
    
    echo "$service_info"
    return 0
}

# Function to get task information
get_task_info() {
    local service_name=$1
    
    local task_arns=$(aws ecs list-tasks \
        --cluster "$CLUSTER_NAME" \
        --service-name "$service_name" \
        --query 'taskArns' \
        --output json 2>/dev/null || echo "[]")
    
    if [[ "$task_arns" == "[]" || "$task_arns" == "null" ]]; then
        echo "[]"
        return 1
    fi
    
    local task_info=$(aws ecs describe-tasks \
        --cluster "$CLUSTER_NAME" \
        --tasks $(echo "$task_arns" | jq -r '.[]' | tr '\n' ' ') \
        --query 'tasks' \
        --output json 2>/dev/null || echo "[]")
    
    echo "$task_info"
    return 0
}

# Function to check service health
check_service_health() {
    local service_name=$1
    local public_ip=$2
    
    case "$service_name" in
        *fullstack*)
            # Check all endpoints for fullstack service
            local api_health=$(curl -s --max-time 5 "http://$public_ip:8000/health" 2>/dev/null && echo "OK" || echo "FAIL")
            local service_desk_health=$(curl -s --max-time 5 "http://$public_ip:8001/health" 2>/dev/null && echo "OK" || echo "FAIL")
            local frontend_health=$(curl -s --max-time 5 "http://$public_ip:80/health" 2>/dev/null && echo "OK" || echo "FAIL")
            
            if [[ "$api_health" == "OK" && "$service_desk_health" == "OK" ]]; then
                if [[ "$frontend_health" == "OK" ]]; then
                    echo "HEALTHY"
                else
                    # Check if frontend main page is accessible
                    local frontend_main=$(curl -s --max-time 5 "http://$public_ip:80" 2>/dev/null && echo "OK" || echo "FAIL")
                    if [[ "$frontend_main" == "OK" ]]; then
                        echo "HEALTHY"
                    else
                        echo "DEGRADED"
                    fi
                fi
            else
                echo "UNHEALTHY"
            fi
            ;;
        *backend*|*app*)
            # Check backend endpoints only
            local api_health=$(curl -s --max-time 5 "http://$public_ip:8000/health" 2>/dev/null && echo "OK" || echo "FAIL")
            local service_desk_health=$(curl -s --max-time 5 "http://$public_ip:8001/health" 2>/dev/null && echo "OK" || echo "FAIL")
            
            if [[ "$api_health" == "OK" && "$service_desk_health" == "OK" ]]; then
                echo "HEALTHY"
            else
                echo "UNHEALTHY"
            fi
            ;;
        *frontend*)
            # Check frontend endpoint only
            local frontend_health=$(curl -s --max-time 5 "http://$public_ip:80/health" 2>/dev/null && echo "OK" || echo "FAIL")
            
            if [[ "$frontend_health" == "OK" ]]; then
                echo "HEALTHY"
            else
                # Check if frontend main page is accessible
                local frontend_main=$(curl -s --max-time 5 "http://$public_ip:80" 2>/dev/null && echo "OK" || echo "FAIL")
                if [[ "$frontend_main" == "OK" ]]; then
                    echo "HEALTHY"
                else
                    echo "UNHEALTHY"
                fi
            fi
            ;;
        *)
            echo "UNKNOWN"
            ;;
    esac
}

# Function to get public IP from task
get_public_ip() {
    local task_arn=$1
    
    local eni_id=$(aws ecs describe-tasks \
        --cluster "$CLUSTER_NAME" \
        --tasks "$task_arn" \
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
            echo "$public_ip"
            return 0
        fi
    fi
    
    echo ""
    return 1
}

# Function to monitor services
monitor_services() {
    print_header "Service Monitoring Started"
    
    # Find all services in the cluster
    local all_services=$(aws ecs list-services \
        --cluster "$CLUSTER_NAME" \
        --query 'serviceArns' \
        --output json 2>/dev/null || echo "[]")
    
    if [[ "$all_services" == "[]" ]]; then
        print_warning "No services found in cluster: $CLUSTER_NAME"
        return 1
    fi
    
    # Extract service names
    local service_names=$(echo "$all_services" | jq -r '.[] | split("/") | .[-1]')
    
    if [[ -z "$service_names" ]]; then
        print_warning "No services found to monitor"
        return 1
    fi
    
    print_status "Found services to monitor:"
    echo "$service_names" | while read -r service_name; do
        print_status "  - $service_name"
    done
    
    # Initialize monitoring variables (using regular arrays for compatibility)
    local restart_counts_file="/tmp/restart_counts_$$"
    local last_task_arns_file="/tmp/last_task_arns_$$"
    local service_states_file="/tmp/service_states_$$"
    
    # Create temporary files for tracking
    touch "$restart_counts_file" "$last_task_arns_file" "$service_states_file"
    
    local start_time=$(date +%s)
    local check_count=0
    
    print_status ""
    print_status "Starting monitoring (Duration: ${MONITOR_DURATION}s, Interval: ${CHECK_INTERVAL}s)"
    print_status "Restart threshold: $RESTART_THRESHOLD"
    print_status ""
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $MONITOR_DURATION ]]; then
            break
        fi
        
        check_count=$((check_count + 1))
        print_status "=== Check #$check_count (${elapsed}s elapsed) ==="
        
        echo "$service_names" | while read -r service_name; do
            if [[ -z "$service_name" ]]; then
                continue
            fi
            
            # Get service information
            local service_info=$(get_service_info "$service_name")
            if [[ "$service_info" == "NOT_FOUND" ]]; then
                print_warning "$service_name: Service not found"
                continue
            fi
            
            # Parse service status
            local service_status=$(echo "$service_info" | jq -r '.status // "UNKNOWN"')
            local running_count=$(echo "$service_info" | jq -r '.runningCount // 0')
            local desired_count=$(echo "$service_info" | jq -r '.desiredCount // 0')
            local pending_count=$(echo "$service_info" | jq -r '.pendingCount // 0')
            
            # Get task information
            local task_info=$(get_task_info "$service_name")
            local task_count=$(echo "$task_info" | jq '. | length')
            
            # Check for task restarts
            if [[ "$task_count" -gt 0 ]]; then
                local current_task_arns=$(echo "$task_info" | jq -r '.[].taskArn' | sort | tr '\n' ',' | sed 's/,$//')
                local last_arns="${last_task_arns[$service_name]:-}"
                
                if [[ -n "$last_arns" && "$current_task_arns" != "$last_arns" ]]; then
                    restart_counts[$service_name]=$((${restart_counts[$service_name]:-0} + 1))
                    print_warning "$service_name: Task restart detected (#${restart_counts[$service_name]})"
                    
                    if [[ ${restart_counts[$service_name]} -ge $RESTART_THRESHOLD ]]; then
                        print_error "$service_name: ALERT - Restart threshold exceeded (${restart_counts[$service_name]} restarts)"
                    fi
                fi
                
                last_task_arns[$service_name]="$current_task_arns"
                
                # Get public IP and check health
                local first_task_arn=$(echo "$task_info" | jq -r '.[0].taskArn // ""')
                if [[ -n "$first_task_arn" ]]; then
                    local public_ip=$(get_public_ip "$first_task_arn")
                    if [[ -n "$public_ip" ]]; then
                        local health_status=$(check_service_health "$service_name" "$public_ip")
                        print_status "$service_name: Status=$service_status, Running=$running_count/$desired_count, Health=$health_status, IP=$public_ip"
                        
                        # Store service state
                        service_states[$service_name]="$service_status|$running_count|$desired_count|$health_status|$public_ip"
                    else
                        print_status "$service_name: Status=$service_status, Running=$running_count/$desired_count, Health=NO_IP"
                        service_states[$service_name]="$service_status|$running_count|$desired_count|NO_IP|"
                    fi
                else
                    print_status "$service_name: Status=$service_status, Running=$running_count/$desired_count, Health=NO_TASKS"
                    service_states[$service_name]="$service_status|$running_count|$desired_count|NO_TASKS|"
                fi
            else
                print_status "$service_name: Status=$service_status, Running=$running_count/$desired_count, Health=NO_TASKS"
                service_states[$service_name]="$service_status|$running_count|$desired_count|NO_TASKS|"
            fi
        done
        
        print_status ""
        
        # Check if we should continue
        if [[ $elapsed -lt $MONITOR_DURATION ]]; then
            sleep "$CHECK_INTERVAL"
        fi
    done
    
    # Final summary
    print_header "Monitoring Summary"
    
    echo "$service_names" | while read -r service_name; do
        if [[ -z "$service_name" ]]; then
            continue
        fi
        
        local restart_count=${restart_counts[$service_name]:-0}
        local final_state="${service_states[$service_name]:-UNKNOWN}"
        
        IFS='|' read -r status running desired health ip <<< "$final_state"
        
        print_status "$service_name:"
        print_status "  Final Status: $status"
        print_status "  Running Tasks: $running/$desired"
        print_status "  Health: $health"
        print_status "  Restarts: $restart_count"
        if [[ -n "$ip" ]]; then
            print_status "  Public IP: $ip"
        fi
        
        if [[ $restart_count -ge $RESTART_THRESHOLD ]]; then
            print_error "  ⚠️  HIGH RESTART COUNT - Investigation needed"
        elif [[ "$health" == "UNHEALTHY" ]]; then
            print_warning "  ⚠️  UNHEALTHY - Check service logs"
        elif [[ "$health" == "HEALTHY" ]]; then
            print_status "  ✅ Service is healthy"
        fi
        
        print_status ""
    done
    
    print_status "Monitoring completed after ${elapsed} seconds"
}

# Function to display service URLs
display_service_urls() {
    print_header "Service Access URLs"
    
    local all_services=$(aws ecs list-services \
        --cluster "$CLUSTER_NAME" \
        --query 'serviceArns' \
        --output json 2>/dev/null || echo "[]")
    
    if [[ "$all_services" == "[]" ]]; then
        print_warning "No services found"
        return 1
    fi
    
    local service_names=$(echo "$all_services" | jq -r '.[] | split("/") | .[-1]')
    
    echo "$service_names" | while read -r service_name; do
        if [[ -z "$service_name" ]]; then
            continue
        fi
        
        local task_info=$(get_task_info "$service_name")
        local task_count=$(echo "$task_info" | jq '. | length')
        
        if [[ "$task_count" -gt 0 ]]; then
            local first_task_arn=$(echo "$task_info" | jq -r '.[0].taskArn // ""')
            if [[ -n "$first_task_arn" ]]; then
                local public_ip=$(get_public_ip "$first_task_arn")
                if [[ -n "$public_ip" ]]; then
                    print_status "$service_name (IP: $public_ip):"
                    
                    case "$service_name" in
                        *fullstack*)
                            print_status "  🌐 Frontend: http://$public_ip:80"
                            print_status "  🔌 API Gateway: http://$public_ip:8000"
                            print_status "  🎫 Service Desk: http://$public_ip:8001"
                            print_status "  📚 API Docs: http://$public_ip:8000/docs"
                            ;;
                        *backend*|*app*)
                            print_status "  🔌 API Gateway: http://$public_ip:8000"
                            print_status "  🎫 Service Desk: http://$public_ip:8001"
                            print_status "  📚 API Docs: http://$public_ip:8000/docs"
                            ;;
                        *frontend*)
                            print_status "  🌐 Frontend: http://$public_ip:80"
                            ;;
                    esac
                    print_status ""
                fi
            fi
        fi
    done
}

# Main function
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Set AWS region
    export AWS_DEFAULT_REGION="$AWS_REGION"
    
    print_header "Aura Team Service Monitor"
    print_status "Environment: $ENVIRONMENT"
    print_status "AWS Region: $AWS_REGION"
    print_status "Monitor Duration: ${MONITOR_DURATION}s"
    print_status "Check Interval: ${CHECK_INTERVAL}s"
    print_status "Restart Threshold: $RESTART_THRESHOLD"
    print_status ""
    
    # Check prerequisites
    check_prerequisites
    
    # Load infrastructure
    load_infrastructure
    
    # Display current service URLs
    display_service_urls
    
    # Start monitoring
    monitor_services
}

# Handle Ctrl+C gracefully
trap 'print_status "Monitoring stopped by user"; exit 0' INT

# Run main function with all arguments
main "$@"
