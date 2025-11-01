# Deployment Quick Reference Guide

## 🚀 Quick Start Commands

### Full-Stack Deployment (Recommended)
```bash
# Deploy complete application with cleanup
./deploy/scripts/deploy-fullstack-aws.sh dev --cleanup-first --force

# Monitor the deployment
./deploy/scripts/monitor-services.sh dev --duration 300
```

### Alternative Deployment Options
```bash
# Backend only (legacy)
./deploy/scripts/deploy-aws-improved.sh dev backend --cleanup-first

# Frontend only (requires backend running)
./deploy/scripts/deploy-aws-improved.sh dev frontend --cleanup-first

# Local development
./deploy-local.sh
```

## 📋 Pre-Deployment Checklist

- [ ] AWS credentials configured (`aws sts get-caller-identity`)
- [ ] Docker running (`docker --version`)
- [ ] Infrastructure exists (`ls deploy/aws/infrastructure-dev.json`)
- [ ] OpenAI API key in Parameter Store
- [ ] No conflicting services running

## 🔍 Health Check Commands

```bash
# Get public IP
PUBLIC_IP=$(aws ecs list-tasks --cluster aura-dev-cluster --service-name aura-fullstack-service --query 'taskArns[0]' --output text | xargs -I {} aws ecs describe-tasks --cluster aura-dev-cluster --tasks {} --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text | xargs -I {} aws ec2 describe-network-interfaces --network-interface-ids {} --query 'NetworkInterfaces[0].Association.PublicIp' --output text)

# Test endpoints
curl -f http://$PUBLIC_IP:80        # Frontend
curl -f http://$PUBLIC_IP:8000/health  # API Gateway
curl -f http://$PUBLIC_IP:8001/health  # Service Desk
curl -f http://$PUBLIC_IP:8000/docs    # API Docs
```

## 🛠️ Troubleshooting Commands

```bash
# Check service status
aws ecs describe-services --cluster aura-dev-cluster --services aura-fullstack-service

# View logs
aws logs tail /ecs/aura-fullstack-dev --follow

# Monitor for restart loops
./deploy/scripts/monitor-services.sh dev --continuous --threshold 2

# Scale down (emergency stop)
aws ecs update-service --cluster aura-dev-cluster --service aura-fullstack-service --desired-count 0

# Clean up and redeploy
./deploy/scripts/cleanup-tasks.sh dev --force
./deploy/scripts/deploy-fullstack-aws.sh dev --cleanup-first --force
```

## 📊 Service URLs After Deployment

| Service | URL Pattern | Description |
|---------|-------------|-------------|
| Frontend | `http://PUBLIC_IP:80` | React UI |
| API Gateway | `http://PUBLIC_IP:8000` | Main API |
| Service Desk | `http://PUBLIC_IP:8001` | Service Desk API |
| API Docs | `http://PUBLIC_IP:8000/docs` | Swagger UI |

## ⚡ Common Issues & Quick Fixes

### Issue: Frontend not accessible
```bash
# Check frontend container
aws ecs describe-tasks --cluster aura-dev-cluster --tasks TASK_ARN
aws logs tail /ecs/aura-fullstack-dev --follow --filter-pattern "frontend"
```

### Issue: Services restarting
```bash
# Monitor restart patterns
./deploy/scripts/monitor-services.sh dev --continuous --threshold 1
```

### Issue: Health checks failing
```bash
# Test manually
curl -v http://PUBLIC_IP:8000/health
curl -v http://PUBLIC_IP:8001/health
curl -v http://PUBLIC_IP:80/health
```

## 🔧 Deployment Script Options

### deploy-fullstack-aws.sh
```bash
# Basic options
./deploy/scripts/deploy-fullstack-aws.sh [dev|staging|prod] [OPTIONS]

# Available options:
--cleanup-first     # Clean existing services first (recommended)
--force            # Skip confirmation prompts
--no-build         # Skip Docker image building
--health-timeout N # Health check timeout (default: 300s)
```

### monitor-services.sh
```bash
# Basic options
./deploy/scripts/monitor-services.sh [dev|staging|prod] [OPTIONS]

# Available options:
--duration N       # Monitor duration in seconds (default: 300)
--interval N       # Check interval in seconds (default: 30)
--threshold N      # Restart threshold before alert (default: 3)
--continuous       # Monitor until Ctrl+C
```

## 📈 Monitoring Dashboard

### Service Status Check
```bash
# Quick status overview
./deploy/scripts/monitor-services.sh dev --duration 60

# Continuous monitoring
./deploy/scripts/monitor-services.sh dev --continuous
```

### Resource Usage
```bash
# Check CPU/Memory usage
aws ecs describe-services --cluster aura-dev-cluster --services aura-fullstack-service --query 'services[0].deployments[0]'

# View task details
aws ecs describe-tasks --cluster aura-dev-cluster --tasks TASK_ARN
```

## 🔄 Rollback Procedures

### Quick Rollback
```bash
# Stop current service
aws ecs update-service --cluster aura-dev-cluster --service aura-fullstack-service --desired-count 0

# Deploy previous version
git checkout PREVIOUS_COMMIT
./deploy/scripts/deploy-fullstack-aws.sh dev --cleanup-first --force
```

### Emergency Cleanup
```bash
# Force cleanup all services
./deploy/scripts/cleanup-tasks.sh dev --force

# Redeploy from scratch
./deploy/scripts/setup-aws-infrastructure.sh dev
./deploy/scripts/deploy-fullstack-aws.sh dev --cleanup-first --force
```

## 💡 Best Practices

1. **Always use `--cleanup-first`** for clean deployments
2. **Monitor after deployment** using the monitoring script
3. **Test all endpoints** after deployment
4. **[ERROR] Failed to process stream: aborted
