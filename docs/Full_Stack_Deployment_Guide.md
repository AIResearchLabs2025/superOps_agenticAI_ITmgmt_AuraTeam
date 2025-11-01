# Full-Stack AWS Deployment Guide

This guide provides comprehensive instructions for deploying the complete Aura Team IT Management application (both frontend and backend) to AWS ECS with proper health checks, monitoring, and loop prevention.

## Overview

The new deployment solution addresses the previous issues where only backend services were being deployed. This guide ensures both frontend and backend are deployed together as a single, cohesive application.

## Key Improvements

### ✅ Issues Fixed
- **Frontend Deployment**: Frontend is now properly included in all deployments
- **Health Checks**: Comprehensive health monitoring for all services
- **Loop Prevention**: Anti-loop protection prevents continuous restart cycles
- **Service Monitoring**: Real-time monitoring with restart detection
- **Proper Dependencies**: Correct container dependencies and startup order
- **Resource Allocation**: Optimized CPU and memory allocation for all containers

### 🆕 New Features
- **Full-Stack Service**: Single ECS service containing all components
- **Comprehensive Monitoring**: Service health monitoring with alerting
- **Graceful Cleanup**: Proper cleanup of existing services before deployment
- **Enhanced Logging**: Structured logging with proper CloudWatch integration
- **Health Endpoints**: All services expose health check endpoints

## Deployment Scripts

### 1. Primary Deployment Script: `deploy-fullstack-aws.sh`

This is the main script for deploying the complete application.

#### Usage
```bash
# Basic full-stack deployment
./deploy/scripts/deploy-fullstack-aws.sh dev

# Clean deployment (recommended)
./deploy/scripts/deploy-fullstack-aws.sh dev --cleanup-first

# Force deployment without prompts
./deploy/scripts/deploy-fullstack-aws.sh dev --cleanup-first --force

# Deploy without rebuilding images
./deploy/scripts/deploy-fullstack-aws.sh dev --no-build

# Deploy with extended health check timeout
./deploy/scripts/deploy-fullstack-aws.sh dev --health-timeout 600
```

#### Parameters
- **Environment**: `dev`, `staging`, `prod`
- **Options**:
  - `--cleanup-first`: Clean up existing services before deployment
  - `--force`: Skip confirmation prompts
  - `--no-build`: Skip Docker image building
  - `--health-timeout N`: Health check timeout in seconds (default: 300)

### 2. Service Monitoring Script: `monitor-services.sh`

This script monitors deployed services for health and restart loops.

#### Usage
```bash
# Monitor for 5 minutes
./deploy/scripts/monitor-services.sh dev

# Monitor for 10 minutes
./deploy/scripts/monitor-services.sh dev --duration 600

# Continuous monitoring
./deploy/scripts/monitor-services.sh dev --continuous

# Custom monitoring parameters
./deploy/scripts/monitor-services.sh dev --duration 300 --interval 15 --threshold 5
```

#### Parameters
- **Options**:
  - `--duration N`: Monitor duration in seconds (default: 300)
  - `--interval N`: Check interval in seconds (default: 30)
  - `--threshold N`: Restart threshold before alert (default: 3)
  - `--continuous`: Monitor continuously until Ctrl+C

## Architecture

### Container Architecture
The full-stack deployment creates a single ECS service with four containers:

```
┌─────────────────────────────────────────────────────────────┐
│                    ECS Task (Fargate)                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────┐ │
│  │  Databases  │  │ API Gateway │  │Service Desk │  │ UI  │ │
│  │             │  │             │  │    Host     │  │     │ │
│  │ PostgreSQL  │  │   Port:     │  │   Port:     │  │Port:│ │
│  │   Redis     │  │    8000     │  │    8001     │  │ 80  │ │
│  │  MongoDB    │  │             │  │             │  │     │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Container Dependencies
```
Databases (PostgreSQL, Redis, MongoDB)
    ↓ (waits for HEALTHY)
API Gateway + Service Desk Host
    ↓ (waits for HEALTHY)
Frontend (React + Nginx)
```

### Resource Allocation
- **Total**: 2048 CPU units (2 vCPU), 4096 MB memory (4 GB)
- **Databases**: 512 CPU, 1024 MB memory
- **API Gateway**: 256 CPU, 512 MB memory
- **Service Desk**: 256 CPU, 512 MB memory
- **Frontend**: 512 CPU, 1024 MB memory

## Deployment Process

### Step 1: Prerequisites Check
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check required tools
docker --version
aws --version
jq --version

# Verify infrastructure exists
ls deploy/aws/infrastructure-dev.json
```

### Step 2: Infrastructure Setup (if needed)
```bash
# Set up AWS infrastructure if not exists
./deploy/scripts/setup-aws-infrastructure.sh dev
```

### Step 3: Deploy Full-Stack Application
```bash
# Recommended deployment command
./deploy/scripts/deploy-fullstack-aws.sh dev --cleanup-first --force
```

### Step 4: Monitor Deployment
```bash
# Monitor the deployment
./deploy/scripts/monitor-services.sh dev --duration 300
```

## Service Endpoints

After successful deployment, the application will be accessible at:

| Service | Endpoint | Description |
|---------|----------|-------------|
| **Frontend UI** | `http://PUBLIC_IP:80` | React application with Material-UI |
| **API Gateway** | `http://PUBLIC_IP:8000` | Main API endpoint |
| **Service Desk API** | `http://PUBLIC_IP:8001` | Service desk specific endpoints |
| **API Documentation** | `http://PUBLIC_IP:8000/docs` | Interactive API documentation |

### Health Check Endpoints
| Service | Health Endpoint | Expected Response |
|---------|----------------|-------------------|
| API Gateway | `http://PUBLIC_IP:8000/health` | HTTP 200 |
| Service Desk | `http://PUBLIC_IP:8001/health` | HTTP 200 |
| Frontend | `http://PUBLIC_IP:80/health` | HTTP 200 "healthy" |

## Monitoring and Troubleshooting

### Real-Time Monitoring
```bash
# Monitor services continuously
./deploy/scripts/monitor-services.sh dev --continuous

# Check service status
aws ecs describe-services --cluster aura-dev-cluster --services aura-fullstack-service

# View logs
aws logs tail /ecs/aura-fullstack-dev --follow
```

### Health Check Verification
```bash
# Get public IP
PUBLIC_IP=$(aws ecs list-tasks --cluster aura-dev-cluster --service-name aura-fullstack-service --query 'taskArns[0]' --output text | xargs -I {} aws ecs describe-tasks --cluster aura-dev-cluster --tasks {} --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text | xargs -I {} aws ec2 describe-network-interfaces --network-interface-ids {} --query 'NetworkInterfaces[0].Association.PublicIp' --output text)

# Test all endpoints
curl -f http://$PUBLIC_IP:8000/health
curl -f http://$PUBLIC_IP:8001/health
curl -f http://$PUBLIC_IP:80/health
curl -f http://$PUBLIC_IP:80
```

### Common Issues and Solutions

#### 1. Frontend Not Accessible
**Symptoms**: Frontend returns 404 or connection refused
**Solutions**:
```bash
# Check if frontend container is running
aws ecs describe-tasks --cluster aura-dev-cluster --tasks TASK_ARN

# Check frontend logs
aws logs tail /ecs/aura-fullstack-dev --follow --filter-pattern "frontend"

# Verify nginx configuration
docker run --rm aura-frontend cat /etc/nginx/conf.d/default.conf
```

#### 2. Service Restart Loops
**Symptoms**: Services continuously restarting
**Solutions**:
```bash
# Monitor restart patterns
./deploy/scripts/monitor-services.sh dev --continuous --threshold 2

# Check resource utilization
aws ecs describe-services --cluster aura-dev-cluster --services aura-fullstack-service

# Scale down and investigate
aws ecs update-service --cluster aura-dev-cluster --service aura-fullstack-service --desired-count 0
```

#### 3. Health Check Failures
**Symptoms**: Health checks failing but services appear to be running
**Solutions**:
```bash
# Check container health
aws ecs describe-tasks --cluster aura-dev-cluster --tasks TASK_ARN --query 'tasks[0].containers[*].{name:name,healthStatus:healthStatus}'

# Test health endpoints manually
curl -v http://PUBLIC_IP:8000/health
curl -v http://PUBLIC_IP:8001/health
curl -v http://PUBLIC_IP:80/health

# Check application logs
aws logs tail /ecs/aura-fullstack-dev --follow
```

## Security Considerations

### Environment Variables
- **OpenAI API Key**: Stored in AWS Systems Manager Parameter Store
- **Database Credentials**: Configured as environment variables (consider using AWS Secrets Manager for production)
- **Debug Mode**: Disabled in production environments

### Network Security
- **Public Access**: Only necessary ports (80, 8000, 8001) are exposed
- **Internal Communication**: Database ports are internal only
- **Security Groups**: Configured to allow only required traffic

### Best Practices
1. **Secrets Management**: Use AWS Secrets Manager for sensitive data
2. **SSL/TLS**: Configure Application Load Balancer with SSL certificates
3. **IAM Roles**: Use least-privilege IAM roles for ECS tasks
4. **Network Isolation**: Consider using private subnets with NAT Gateway

## Cost Optimization

### Resource Management
```bash
# Scale down during off-hours
aws ecs update-service --cluster aura-dev-cluster --service aura-fullstack-service --desired-count 0

# Scale up during work hours
aws ecs update-service --cluster aura-dev-cluster --service aura-fullstack-service --desired-count 1
```

### Monitoring Costs
- **CloudWatch Logs**: 7-day retention policy configured
- **ECS Fargate**: Pay-per-use pricing model
- **Data Transfer**: Monitor outbound data transfer costs

## Backup and Recovery

### Database Backup
```bash
# Create database backup (manual process)
# Connect to running task and export data
aws ecs execute-command --cluster aura-dev-cluster --task TASK_ARN --container databases --interactive --command "/bin/bash"

# Inside container:
pg_dump -U aura_user -h localhost aura_servicedesk > backup.sql
```

### Disaster Recovery
1. **Infrastructure**: All infrastructure is defined as code
2. **Application Code**: Stored in version control
3. **Data**: Implement regular database backups
4. **Images**: Stored in ECR with versioning

## CI/CD Integration

### GitHub Actions Integration
```yaml
# Example workflow step
- name: Deploy Full-Stack Application
  run: |
    ./deploy/scripts/deploy-fullstack-aws.sh ${{ env.ENVIRONMENT }} --cleanup-first --force
    
- name: Monitor Deployment
  run: |
    ./deploy/scripts/monitor-services.sh ${{ env.ENVIRONMENT }} --duration 300
```

### Deployment Pipeline
1. **Build**: Docker images built and pushed to ECR
2. **Test**: Health checks and integration tests
3. **Deploy**: Full-stack deployment with monitoring
4. **Verify**: Automated health verification

## Rollback Procedures

### Quick Rollback
```bash
# Stop current deployment
aws ecs update-service --cluster aura-dev-cluster --service aura-fullstack-service --desired-count 0

# Deploy previous version
git checkout PREVIOUS_COMMIT
./deploy/scripts/deploy-fullstack-aws.sh dev --cleanup-first --force
```

### Complete Rollback
```bash
# Clean up current deployment
./deploy/scripts/cleanup-tasks.sh dev --force

# Deploy from backup or previous version
./deploy/scripts/deploy-fullstack-aws.sh dev --cleanup-first --force
```

## Performance Tuning

### Container Optimization
- **CPU**: Monitor CPU utilization and adjust allocation
- **Memory**: Monitor memory usage and optimize container sizes
- **Startup Time**: Optimize Docker images for faster startup

### Application Performance
- **Database Connections**: Configure connection pooling
- **Caching**: Utilize Redis for application caching
- **Static Assets**: Configure CDN for frontend assets

## Support and Maintenance

### Regular Maintenance Tasks
1. **Update Dependencies**: Regularly update Docker base images
2. **Security Patches**: Apply security updates promptly
3. **Performance Review**: Monitor and optimize resource usage
4. **Log Analysis**: Review application logs for issues

### Monitoring Alerts
Set up CloudWatch alarms for:
- **High CPU Usage**: > 80% for 5 minutes
- **High Memory Usage**: > 90% for 5 minutes
- **Service Restarts**: > 3 restarts in 10 minutes
- **Health Check Failures**: > 5 consecutive failures

## Conclusion

This full-stack deployment solution provides a robust, monitored, and maintainable way to deploy the complete Aura Team application to AWS. The combination of proper health checks, monitoring, and loop prevention ensures reliable deployments and stable operation.

For additional support or questions, refer to the troubleshooting section or check the application logs using the provided monitoring commands.
