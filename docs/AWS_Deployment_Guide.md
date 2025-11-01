# AWS Deployment Guide for Aura Team Project

This guide provides comprehensive instructions for deploying the Aura Team IT Management application to AWS ECS with proper cleanup, health checks, and prevention of task recreation loops.

## Prerequisites

### 1. AWS CLI Configuration

First, ensure your AWS credentials are properly configured:

```bash
# Check if AWS CLI is installed
aws --version

# Configure AWS credentials (if not already done)
aws configure

# Or if using SSO
aws sso login --profile your-profile

# Verify credentials are working
aws sts get-caller-identity
```

**Important**: If you get an "ExpiredToken" error, refresh your credentials:
- For regular credentials: Run `aws configure` again
- For SSO: Run `aws sso login --profile your-profile`
- For temporary credentials: Refresh your session

### 2. Required Tools

Ensure these tools are installed:

```bash
# Docker
docker --version

# jq (for JSON processing)
jq --version

# If jq is not installed:
# macOS: brew install jq
# Ubuntu: sudo apt-get install jq
# CentOS: sudo yum install jq
```

### 3. Environment Setup

Ensure your infrastructure is set up:

```bash
# Check if infrastructure exists
ls deploy/aws/infrastructure-dev.json

# If not exists, run infrastructure setup
./deploy/scripts/setup-aws-infrastructure.sh dev
```

## Deployment Options

### Option 1: Clean Deployment (Recommended)

This option cleans up existing services before deploying new ones:

```bash
# Deploy backend services with cleanup
./deploy/scripts/deploy-aws-improved.sh dev backend --cleanup-first

# Deploy full application with cleanup
./deploy/scripts/deploy-aws-improved.sh dev fullstack --cleanup-first --force
```

### Option 2: Quick Deployment

Deploy without cleanup (use only if no existing services):

```bash
# Deploy backend only
./deploy/scripts/deploy-aws-improved.sh dev backend

# Deploy full application
./deploy/scripts/deploy-aws-improved.sh dev fullstack
```

### Option 3: Frontend Only Deployment

Deploy only the frontend (requires backend to be already running):

```bash
./deploy/scripts/deploy-aws-improved.sh dev frontend --cleanup-first
```

## Deployment Script Options

### Command Syntax

```bash
./deploy/scripts/deploy-aws-improved.sh [ENVIRONMENT] [DEPLOYMENT_TYPE] [OPTIONS]
```

### Parameters

**ENVIRONMENT:**
- `dev` - Development environment (default)
- `staging` - Staging environment
- `prod` - Production environment

**DEPLOYMENT_TYPE:**
- `backend` - Deploy only backend services (default)
- `frontend` - Deploy only frontend
- `fullstack` - Deploy complete application

**OPTIONS:**
- `--cleanup-first` - Clean up existing services before deployment
- `--force` - Skip confirmation prompts
- `--no-build` - Skip Docker image building (use existing images)
- `--health-timeout N` - Health check timeout in seconds (default: 300)

### Examples

```bash
# Clean deployment with confirmation
./deploy/scripts/deploy-aws-improved.sh dev backend --cleanup-first

# Force deployment without prompts
./deploy/scripts/deploy-aws-improved.sh dev fullstack --cleanup-first --force

# Deploy without rebuilding images
./deploy/scripts/deploy-aws-improved.sh dev backend --no-build

# Deploy with extended health check timeout
./deploy/scripts/deploy-aws-improved.sh dev fullstack --health-timeout 600
```

## Deployment Process

The deployment script performs these steps:

### 1. Prerequisites Check
- Verifies AWS CLI installation
- Checks Docker availability
- Validates AWS credentials
- Confirms jq installation

### 2. Infrastructure Loading
- Loads VPC, subnets, and security group information
- Validates ECS cluster exists

### 3. Cleanup (if requested)
- Lists existing services
- Scales down services to 0 tasks
- Deletes services
- Force stops remaining tasks

### 4. ECR Repository Creation
- Creates ECR repositories if they don't exist:
  - `aura-api-gateway`
  - `aura-service-desk-host`
  - `aura-databases`
  - `aura-frontend`

### 5. Image Building and Pushing
- Builds Docker images for selected components
- Tags images with latest
- Pushes to ECR repositories

### 6. ECS Deployment
- Creates CloudWatch log groups
- Registers task definitions
- Creates ECS services
- Configures networking and security

### 7. Health Monitoring
- Waits for service stabilization
- Performs health checks on endpoints
- Reports deployment status and access URLs

## Troubleshooting

### Common Issues

#### 1. AWS Credentials Expired

**Error**: `ExpiredToken when calling the GetCallerIdentity operation`

**Solution**:
```bash
# For regular AWS credentials
aws configure

# For SSO
aws sso login --profile your-profile

# Verify credentials
aws sts get-caller-identity
```

#### 2. Infrastructure Not Found

**Error**: `Infrastructure file not found: deploy/aws/infrastructure-dev.json`

**Solution**:
```bash
# Set up AWS infrastructure first
./deploy/scripts/setup-aws-infrastructure.sh dev
```

#### 3. ECR Login Issues

**Error**: `no basic auth credentials`

**Solution**:
```bash
# Manual ECR login
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-2.amazonaws.com
```

#### 4. Service Already Exists

**Error**: `Service already exists`

**Solution**:
```bash
# Use cleanup option
./deploy/scripts/deploy-aws-improved.sh dev backend --cleanup-first

# Or manually clean up
./deploy/scripts/cleanup-tasks.sh dev --force
```

#### 5. Health Check Failures

**Error**: Health checks failing after deployment

**Solution**:
```bash
# Check service logs
aws logs tail /ecs/aura-app-dev --follow

# Check task status
aws ecs describe-services --cluster aura-dev-cluster --services aura-app-service

# Increase health check timeout
./deploy/scripts/deploy-aws-improved.sh dev backend --health-timeout 600
```

### Manual Cleanup

If automatic cleanup fails, use manual cleanup:

```bash
# Clean up all services and tasks
./deploy/scripts/cleanup-tasks.sh dev --force

# Clean up specific environment
./deploy/scripts/cleanup-tasks.sh staging --all
```

## Monitoring and Verification

### 1. Check Service Status

```bash
# List running services
aws ecs list-services --cluster aura-dev-cluster

# Describe specific service
aws ecs describe-services --cluster aura-dev-cluster --services aura-app-service

# List running tasks
aws ecs list-tasks --cluster aura-dev-cluster
```

### 2. View Logs

```bash
# View all logs
aws logs tail /ecs/aura-app-dev --follow

# View specific container logs
aws logs tail /ecs/aura-app-dev --follow --filter-pattern "api-gateway"
aws logs tail /ecs/aura-app-dev --follow --filter-pattern "service-desk"
aws logs tail /ecs/aura-app-dev --follow --filter-pattern "databases"
```

### 3. Health Check Endpoints

After successful deployment, verify these endpoints:

```bash
# Get public IP from deployment output, then test:
curl http://PUBLIC_IP:8000/health    # API Gateway
curl http://PUBLIC_IP:8001/health    # Service Desk
curl http://PUBLIC_IP:8000/docs      # API Documentation
curl http://PUBLIC_IP:80             # Frontend (if deployed)
```

## Security Considerations

### 1. OpenAI API Key

The OpenAI API key is stored in AWS Systems Manager Parameter Store:

```bash
# Set the API key (one-time setup)
aws ssm put-parameter \
    --name "/aura/dev/openai-api-key" \
    --value "your-openai-api-key" \
    --type "SecureString" \
    --region us-east-2
```

### 2. Network Security

- Services run in public subnets with security groups
- Only necessary ports are exposed (8000, 8001, 80)
- Database ports (5432, 6379, 27017) are internal only

### 3. IAM Roles

The deployment uses these IAM roles:
- `ecsTaskExecutionRole` - For ECS task execution
- `ecsTaskRole` - For application permissions

## Cost Optimization

### 1. Resource Sizing

Current configuration:
- **CPU**: 1024 units (1 vCPU)
- **Memory**: 2048 MB (2 GB)
- **Storage**: Ephemeral only

### 2. Auto-scaling (Future Enhancement)

Consider implementing auto-scaling based on:
- CPU utilization
- Memory utilization
- Request count

### 3. Scheduled Scaling

For development environments:
```bash
# Scale down during off-hours
aws ecs update-service --cluster aura-dev-cluster --service aura-app-service --desired-count 0

# Scale up during work hours
aws ecs update-service --cluster aura-dev-cluster --service aura-app-service --desired-count 1
```

## Rollback Procedures

### 1. Quick Rollback

```bash
# Stop current deployment
aws ecs update-service --cluster aura-dev-cluster --service aura-app-service --desired-count 0

# Deploy previous version
./deploy/scripts/deploy-aws-improved.sh dev backend --no-build
```

### 2. Complete Rollback

```bash
# Clean up current deployment
./deploy/scripts/cleanup-tasks.sh dev --force

# Deploy from backup or previous commit
git checkout PREVIOUS_COMMIT
./deploy/scripts/deploy-aws-improved.sh dev backend --cleanup-first
```

## Best Practices

### 1. Pre-deployment Checklist

- [ ] AWS credentials are valid and not expired
- [ ] Infrastructure is set up and accessible
- [ ] OpenAI API key is configured in Parameter Store
- [ ] Local Docker daemon is running
- [ ] No conflicting services are running

### 2. Deployment Workflow

1. **Test Locally First**
   ```bash
   ./deploy-local.sh
   ```

2. **Clean Deployment**
   ```bash
   ./deploy/scripts/deploy-aws-improved.sh dev backend --cleanup-first
   ```

3. **Verify Health**
   - Check all health endpoints
   - Review CloudWatch logs
   - Test key functionality

4. **Monitor Performance**
   - Watch CloudWatch metrics
   - Monitor application logs
   - Check resource utilization

### 3. Maintenance

- **Regular Updates**: Deploy updates during low-traffic periods
- **Log Retention**: CloudWatch logs are retained for 7 days
- **Security Updates**: Regularly update base Docker images
- **Backup Strategy**: Consider database backup procedures

## Support and Troubleshooting

For additional support:

1. **Check CloudWatch Logs**: `/ecs/aura-app-dev`
2. **Review ECS Console**: AWS ECS service dashboard
3. **Validate Task Definitions**: Ensure proper resource allocation
4. **Network Connectivity**: Verify security group rules
5. **IAM Permissions**: Confirm role permissions are adequate

## Next Steps

After successful deployment:

1. **Set up monitoring and alerting**
2. **Configure auto-scaling policies**
3. **Implement CI/CD pipeline**
4. **Set up backup and disaster recovery**
5. **Configure SSL/TLS certificates**
6. **Implement load balancing for production**
