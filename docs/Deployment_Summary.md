# AWS Deployment Summary for Aura Team Project

## Quick Start Guide

This document provides a quick reference for deploying the Aura Team IT Management application to AWS ECS.

## Prerequisites Check

Before deploying, run the verification script to check your setup:

```bash
./deploy/scripts/verify-aws-setup.sh dev
```

This will check:
- ✅ AWS CLI installation and credentials
- ✅ Docker installation and daemon status
- ✅ Required tools (jq)
- ✅ AWS infrastructure setup
- ✅ ECR repositories
- ✅ OpenAI API key configuration
- ✅ Current deployment status

## Common Issues and Solutions

### 1. AWS Credentials Expired

**Problem**: `ExpiredToken when calling the GetCallerIdentity operation`

**Solution**:
```bash
# For regular AWS credentials
aws configure

# For SSO users
aws sso login --profile your-profile

# Verify credentials work
aws sts get-caller-identity
```

### 2. Missing Infrastructure

**Problem**: `Infrastructure file not found`

**Solution**:
```bash
./deploy/scripts/setup-aws-infrastructure.sh dev
```

### 3. Docker Not Running

**Problem**: `Docker daemon not running`

**Solution**:
- Start Docker Desktop (macOS/Windows)
- Start Docker service (Linux): `sudo systemctl start docker`

## Deployment Commands

### Option 1: Clean Deployment (Recommended)

Cleans up existing services before deploying:

```bash
# Backend only with cleanup
./deploy/scripts/deploy-aws-improved.sh dev backend --cleanup-first

# Full application with cleanup (no prompts)
./deploy/scripts/deploy-aws-improved.sh dev fullstack --cleanup-first --force
```

### Option 2: Quick Deployment

For fresh deployments without existing services:

```bash
# Backend only
./deploy/scripts/deploy-aws-improved.sh dev backend

# Full application
./deploy/scripts/deploy-aws-improved.sh dev fullstack
```

### Option 3: Frontend Only

Deploy only frontend (requires backend running):

```bash
./deploy/scripts/deploy-aws-improved.sh dev frontend --cleanup-first
```

## Deployment Process Overview

The deployment script automatically:

1. **Validates Prerequisites** - Checks AWS credentials, Docker, tools
2. **Loads Infrastructure** - Reads VPC, subnets, security groups
3. **Cleans Up** (if requested) - Removes existing services and tasks
4. **Creates ECR Repos** - Sets up container repositories
5. **Builds Images** - Creates and pushes Docker images
6. **Deploys to ECS** - Creates task definitions and services
7. **Monitors Health** - Waits for services to stabilize
8. **Verifies Endpoints** - Tests health check URLs

## Expected Output

After successful deployment, you'll see:

```
🎉 Application deployed successfully!

Access your application at:
  🔌 API Gateway: http://PUBLIC_IP:8000
  🎫 Service Desk: http://PUBLIC_IP:8001
  📚 API Documentation: http://PUBLIC_IP:8000/docs
  🌐 Frontend UI: http://PUBLIC_IP:80 (if fullstack)

Task ARN: arn:aws:ecs:us-east-2:ACCOUNT:task/aura-dev-cluster/TASK_ID
Public IP: XXX.XXX.XXX.XXX
```

## Health Check Verification

Test the deployed services:

```bash
# Replace PUBLIC_IP with the actual IP from deployment output
curl http://PUBLIC_IP:8000/health    # API Gateway
curl http://PUBLIC_IP:8001/health    # Service Desk
curl http://PUBLIC_IP:8000/docs      # API Documentation
curl http://PUBLIC_IP:80             # Frontend (if deployed)
```

## Monitoring and Logs

### View Real-time Logs

```bash
# All services
aws logs tail /ecs/aura-app-dev --follow

# Specific service
aws logs tail /ecs/aura-app-dev --follow --filter-pattern "api-gateway"
```

### Check Service Status

```bash
# List services
aws ecs list-services --cluster aura-dev-cluster

# Service details
aws ecs describe-services --cluster aura-dev-cluster --services aura-app-service

# Running tasks
aws ecs list-tasks --cluster aura-dev-cluster
```

## Cleanup and Rollback

### Clean Up Deployment

```bash
# Clean up all services and tasks
./deploy/scripts/cleanup-tasks.sh dev --force

# Clean up with confirmation
./deploy/scripts/cleanup-tasks.sh dev
```

### Scale Down (Cost Saving)

```bash
# Scale to 0 (stops billing for compute)
aws ecs update-service --cluster aura-dev-cluster --service aura-app-service --desired-count 0

# Scale back up
aws ecs update-service --cluster aura-dev-cluster --service aura-app-service --desired-count 1
```

## Troubleshooting

### Deployment Fails

1. **Check Prerequisites**: Run `./deploy/scripts/verify-aws-setup.sh dev`
2. **View Logs**: `aws logs tail /ecs/aura-app-dev --follow`
3. **Check Task Status**: `aws ecs describe-tasks --cluster aura-dev-cluster --tasks TASK_ARN`
4. **Verify Security Groups**: Ensure ports 8000, 8001, 80 are open

### Services Not Starting

1. **Check Resource Limits**: Ensure sufficient CPU/memory
2. **Verify Environment Variables**: Check task definition
3. **Database Connectivity**: Ensure database container is healthy
4. **OpenAI API Key**: Verify key is set in Parameter Store

### Health Checks Failing

1. **Wait Longer**: Services may take 2-3 minutes to fully start
2. **Check Dependencies**: Database must be healthy first
3. **Network Issues**: Verify security group rules
4. **Application Errors**: Check application logs

## Security Notes

- **OpenAI API Key**: Stored securely in AWS Parameter Store
- **Network Security**: Services run in public subnets with security groups
- **Database Access**: Database ports are internal-only
- **IAM Roles**: Uses least-privilege access patterns

## Cost Optimization

- **Development**: Scale down when not in use
- **Resource Sizing**: Current config uses 1 vCPU, 2GB RAM
- **Log Retention**: CloudWatch logs retained for 7 days
- **Auto-scaling**: Consider implementing for production

## Next Steps

After successful deployment:

1. **Test Functionality**: Create tickets, test AI analysis
2. **Set Up Monitoring**: CloudWatch alarms and dashboards
3. **Configure Backups**: Database backup strategy
4. **SSL/TLS**: Add certificates for production
5. **CI/CD Pipeline**: Automate deployments
6. **Load Balancing**: Add ALB for production traffic

## Support Resources

- **Full Documentation**: `docs/AWS_Deployment_Guide.md`
- **Cleanup Script**: `deploy/scripts/cleanup-tasks.sh`
- **Verification Script**: `deploy/scripts/verify-aws-setup.sh`
- **AWS Console**: ECS, CloudWatch, Parameter Store
- **Local Testing**: `./deploy-local.sh`

## Quick Reference Commands

```bash
# Check setup
./deploy/scripts/verify-aws-setup.sh dev

# Deploy with cleanup
./deploy/scripts/deploy-aws-improved.sh dev fullstack --cleanup-first --force

# Monitor logs
aws logs tail /ecs/aura-app-dev --follow

# Check status
aws ecs describe-services --cluster aura-dev-cluster --services aura-app-service

# Clean up
./deploy/scripts/cleanup-tasks.sh dev --force

# Scale down
aws ecs update-service --cluster aura-dev-cluster --service aura-app-service --desired-count 0
