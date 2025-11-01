#!/bin/bash
# AWS Setup Verification Script for Aura Team Project
# Checks prerequisites and provides guidance for deployment

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to check AWS CLI
check_aws_cli() {
    print_header "Checking AWS CLI"
    
    if command -v aws &> /dev/null; then
        local aws_version=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
        print_status "AWS CLI installed: v$aws_version"
        return 0
    else
        print_error "AWS CLI is not installed"
        print_info "Install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        return 1
    fi
}

# Function to check AWS credentials
check_aws_credentials() {
    print_header "Checking AWS Credentials"
    
    if aws sts get-caller-identity &> /dev/null; then
        local account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
        local user_arn=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)
        local region=${AWS_DEFAULT_REGION:-$(aws configure get region 2>/dev/null || echo "us-east-2")}
        
        print_status "AWS credentials are valid"
        print_info "Account ID: $account_id"
        print_info "User/Role: $user_arn"
        print_info "Region: $region"
        
        # Set global variables for later use
        export AWS_ACCOUNT_ID="$account_id"
        export AWS_REGION="$region"
        
        return 0
    else
        print_error "AWS credentials are not configured or expired"
        print_info "Solutions:"
        print_info "  1. Run: aws configure"
        print_info "  2. For SSO: aws sso login --profile your-profile"
        print_info "  3. Check environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"
        return 1
    fi
}

# Function to check Docker
check_docker() {
    print_header "Checking Docker"
    
    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
            print_status "Docker is running: v$docker_version"
            return 0
        else
            print_error "Docker is installed but not running"
            print_info "Start Docker Desktop or Docker daemon"
            return 1
        fi
    else
        print_error "Docker is not installed"
        print_info "Install Docker: https://docs.docker.com/get-docker/"
        return 1
    fi
}

# Function to check jq
check_jq() {
    print_header "Checking jq"
    
    if command -v jq &> /dev/null; then
        local jq_version=$(jq --version | cut -d'-' -f2)
        print_status "jq installed: v$jq_version"
        return 0
    else
        print_error "jq is not installed"
        print_info "Install jq:"
        print_info "  macOS: brew install jq"
        print_info "  Ubuntu: sudo apt-get install jq"
        print_info "  CentOS: sudo yum install jq"
        return 1
    fi
}

# Function to check infrastructure
check_infrastructure() {
    local environment=${1:-dev}
    
    print_header "Checking AWS Infrastructure"
    
    local infrastructure_file="deploy/aws/infrastructure-${environment}.json"
    
    if [[ -f "$infrastructure_file" ]]; then
        print_status "Infrastructure file exists: $infrastructure_file"
        
        # Validate infrastructure file content
        if jq empty "$infrastructure_file" 2>/dev/null; then
            local vpc_id=$(jq -r '.vpc_id' "$infrastructure_file")
            local cluster_name=$(jq -r '.ecs_cluster' "$infrastructure_file")
            
            print_info "VPC ID: $vpc_id"
            print_info "ECS Cluster: $cluster_name"
            
            # Check if ECS cluster exists
            if aws ecs describe-clusters --clusters "$cluster_name" --query 'clusters[0].status' --output text 2>/dev/null | grep -q "ACTIVE"; then
                print_status "ECS cluster is active: $cluster_name"
                return 0
            else
                print_warning "ECS cluster may not be active or accessible"
                print_info "Check AWS ECS console or run infrastructure setup"
                return 1
            fi
        else
            print_error "Infrastructure file is invalid JSON"
            return 1
        fi
    else
        print_error "Infrastructure file not found: $infrastructure_file"
        print_info "Run: ./deploy/scripts/setup-aws-infrastructure.sh $environment"
        return 1
    fi
}

# Function to check ECR repositories
check_ecr_repositories() {
    print_header "Checking ECR Repositories"
    
    local repositories=("aura-api-gateway" "aura-service-desk-host" "aura-databases" "aura-frontend")
    local missing_repos=()
    
    for repo in "${repositories[@]}"; do
        if aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" &> /dev/null; then
            print_status "ECR repository exists: $repo"
        else
            print_warning "ECR repository missing: $repo"
            missing_repos+=("$repo")
        fi
    done
    
    if [[ ${#missing_repos[@]} -eq 0 ]]; then
        print_status "All ECR repositories exist"
        return 0
    else
        print_info "Missing repositories will be created during deployment"
        return 1
    fi
}

# Function to check OpenAI API key
check_openai_key() {
    local environment=${1:-dev}
    
    print_header "Checking OpenAI API Key"
    
    local parameter_name="/aura/${environment}/openai-api-key"
    
    if aws ssm get-parameter --name "$parameter_name" --region "$AWS_REGION" &> /dev/null; then
        print_status "OpenAI API key is configured in Parameter Store"
        return 0
    else
        print_warning "OpenAI API key not found in Parameter Store"
        print_info "Set it with:"
        print_info "  aws ssm put-parameter --name '$parameter_name' --value 'your-key' --type 'SecureString' --region '$AWS_REGION'"
        return 1
    fi
}

# Function to check current deployments
check_current_deployments() {
    local environment=${1:-dev}
    
    print_header "Checking Current Deployments"
    
    local cluster_name="aura-${environment}-cluster"
    local services=$(aws ecs list-services --cluster "$cluster_name" --query 'serviceArns' --output text 2>/dev/null || echo "")
    
    if [[ -n "$services" && "$services" != "None" ]]; then
        print_warning "Found existing services in cluster: $cluster_name"
        for service_arn in $services; do
            local service_name=$(basename "$service_arn")
            local service_status=$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" --query 'services[0].status' --output text 2>/dev/null || echo "UNKNOWN")
            local running_count=$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" --query 'services[0].runningCount' --output text 2>/dev/null || echo "0")
            
            print_info "  $service_name: $service_status (Running: $running_count)"
        done
        print_info "Use --cleanup-first option to clean up before deployment"
        return 1
    else
        print_status "No existing services found"
        return 0
    fi
}

# Function to provide deployment recommendations
provide_recommendations() {
    local environment=${1:-dev}
    local has_existing_services=$1
    
    print_header "Deployment Recommendations"
    
    print_info "Based on the checks above, here are the recommended next steps:"
    echo ""
    
    if [[ "$has_existing_services" == "1" ]]; then
        print_info "🧹 Clean Deployment (Recommended):"
        echo "   ./deploy/scripts/deploy-aws-improved.sh $environment backend --cleanup-first"
        echo ""
        print_info "🚀 Force Deployment (No prompts):"
        echo "   ./deploy/scripts/deploy-aws-improved.sh $environment fullstack --cleanup-first --force"
    else
        print_info "🚀 Fresh Deployment:"
        echo "   ./deploy/scripts/deploy-aws-improved.sh $environment backend"
        echo ""
        print_info "🌐 Full Stack Deployment:"
        echo "   ./deploy/scripts/deploy-aws-improved.sh $environment fullstack"
    fi
    
    echo ""
    print_info "📊 Monitor Deployment:"
    echo "   aws logs tail /ecs/aura-app-$environment --follow"
    echo ""
    print_info "🔍 Check Service Status:"
    echo "   aws ecs describe-services --cluster aura-$environment-cluster --services aura-app-service"
    echo ""
    print_info "📚 Full Documentation:"
    echo "   See docs/AWS_Deployment_Guide.md for complete instructions"
}

# Function to run all checks
run_all_checks() {
    local environment=${1:-dev}
    local checks_passed=0
    local total_checks=7
    local has_existing_services=0
    
    print_header "AWS Deployment Readiness Check"
    print_info "Environment: $environment"
    print_info "Region: ${AWS_DEFAULT_REGION:-us-east-2}"
    echo ""
    
    # Run all checks
    check_aws_cli && ((checks_passed++))
    check_aws_credentials && ((checks_passed++))
    check_docker && ((checks_passed++))
    check_jq && ((checks_passed++))
    check_infrastructure "$environment" && ((checks_passed++))
    check_ecr_repositories && ((checks_passed++))
    check_openai_key "$environment" && ((checks_passed++))
    
    # Check current deployments (doesn't count towards pass/fail)
    if ! check_current_deployments "$environment"; then
        has_existing_services=1
    fi
    
    echo ""
    print_header "Summary"
    
    if [[ $checks_passed -eq $total_checks ]]; then
        print_status "All checks passed! ($checks_passed/$total_checks)"
        print_status "Ready for deployment! 🚀"
    elif [[ $checks_passed -ge 4 ]]; then
        print_warning "Most checks passed ($checks_passed/$total_checks)"
        print_warning "You can proceed with deployment, but some features may not work"
    else
        print_error "Several checks failed ($checks_passed/$total_checks)"
        print_error "Please resolve the issues above before deployment"
    fi
    
    echo ""
    provide_recommendations "$environment" "$has_existing_services"
    
    return $((total_checks - checks_passed))
}

# Main function
main() {
    local environment="dev"
    
    # Parse arguments
    case "${1:-}" in
        "dev"|"staging"|"prod")
            environment="$1"
            ;;
        "-h"|"--help"|"help")
            echo "Usage: $0 [ENVIRONMENT]"
            echo ""
            echo "ENVIRONMENT:"
            echo "  dev      - Development environment (default)"
            echo "  staging  - Staging environment"
            echo "  prod     - Production environment"
            echo ""
            echo "This script checks AWS deployment prerequisites and provides guidance."
            exit 0
            ;;
        "")
            # Use default
            ;;
        *)
            print_error "Invalid environment: $1"
            print_info "Valid environments: dev, staging, prod"
            exit 1
            ;;
    esac
    
    # Set AWS region
    export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-2}
    
    # Run all checks
    run_all_checks "$environment"
}

# Run main function with all arguments
main "$@"
