# Quick Deployment Guide - AWS Dynamic IP Solution

This guide provides step-by-step instructions to deploy the Aura application to AWS with the dynamic IP solution that fixes knowledge base functionality.

## Prerequisites ✅

1. **AWS CLI configured** with valid credentials
2. **Docker** installed and running
3. **jq** installed for JSON processing
4. **Infrastructure setup** completed (VPC, subnets, security groups)

```bash
# Verify prerequisites
aws sts get-caller-identity  # Should return your AWS account info
docker --version            # Should show Docker version
jq --version               # Should show jq version
```

## Quick Start 🚀

### Step 1: Deploy Backend Services (Recommended)
This deploys the core services with dynamic IP handling:

```bash
./deploy/scripts/deploy-aws-with-alb.sh dev backend --cleanup-first --force
```

**What this does:**
- Cleans up any existing services
- Builds and pushes Docker images to ECR
- Deploys API Gateway, Service Desk, and Database containers
- Configures proper networking for dynamic IP handling
- Performs health checks and provides access URLs

### Step 2: Deploy Full Application (Optional)
If you want to include the frontend:

```bash
./deploy/scripts/deploy-aws-with-alb.sh dev fullstack --cleanup-first --force
```

### Step 3: Deploy with Load Balancer (Production)
For production-ready deployment with ALB:

```bash
./deploy/scripts/deploy-aws-with-alb.sh dev fullstack --cleanup-first --create-alb --force
```

## Deployment Options 🛠️

### Standard Options
| Option | Description | Use Case |
|--------|-------------|----------|
| `dev backend` | Backend services only | API testing, development |
| `dev fullstack` | Complete application | Full testing |
| `dev frontend` | Frontend only | UI updates |

### Advanced Flags
| Flag | Description | When to Use |
|------|-------------|-------------|
| `--cleanup-first` | Remove existing services | Fresh deployment, troubleshooting |
| `--force` | Skip confirmation prompts | Automated deployments |
| `--no-build` | Skip Docker image building | Quick updates, testing |
| `--create-alb` | Create Application Load Balancer | Production deployments |

## Verification Steps ✓

### 1. Check Deployment Status
```bash
# View ECS service status
aws ecs describe-services --cluster aura-dev-cluster --services aura-app-service

# Check running tasks
aws ecs list-tasks --cluster aura-dev-cluster --service-name aura-app-service
```

### 2. Test Health Endpoints
After deployment, the script will provide access URLs. Test them:

```bash
# Replace {PUBLIC_IP} with the IP from deployment output
curl http://{PUBLIC_IP}:8000/health    # API Gateway
curl http://{PUBLIC_IP}:8001/health    # Service Desk
```

### 3. Test Knowledge Base Functionality
The key endpoints that were failing:

```bash
# Search articles (the main issue)
curl -X POST http://{PUBLIC_IP}:8000/api/v1/kb/search \
  -H "Content-Type: application/json" \
  -d '{"query": "password"}'

# Browse articles
curl http://{PUBLIC_IP}:8000/api/v1/kb/articles?limit=5
```

### 4. Frontend Testing (if deployed)
Open browser and navigate to:
- `http://{PUBLIC_IP}:80` (Frontend)
- Check browser console for dynamic configuration logs

## Troubleshooting 🔧

### Common Issues

#### 1. "Infrastructure file not found"
```bash
# Run infrastructure setup first
./deploy/scripts/setup-aws-infrastructure.sh dev
```

#### 2. "AWS credentials expired"
```bash
# Refresh credentials
aws sso login --profile your-profile
# OR
aws configure
```

#### 3. "Health checks failing"
```bash
# Check ECS logs
aws logs tail /ecs/aura-app-dev --follow

# Check task details
aws ecs describe-tasks --cluster aura-dev-cluster --tasks {TASK_ARN}
```

#### 4. "Knowledge Base still not working"
```bash
# Check service connectivity
curl -v http://{PUBLIC_IP}:8001/health

# Check API Gateway logs
aws logs tail /ecs/aura-app-dev --follow --filter-pattern "api-gateway"
```

### Debug Commands
```bash
# Get public IP of running task
TASK_ARN=$(aws ecs list-tasks --cluster aura-dev-cluster --service-name aura-app-service --query 'taskArns[0]' --output text)
ENI_ID=$(aws ecs describe-tasks --cluster aura-dev-cluster --tasks $TASK_ARN --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
echo "Public IP: $PUBLIC_IP"
```

## Expected Output 📋

### Successful Deployment
```
✅ Prerequisites check passed
✅ Infrastructure loaded: VPC=vpc-xxx, Subnets=subnet-xxx, SG=sg-xxx
✅ ECR repositories ready
✅ Images built and pushed successfully
✅ Log group created: /ecs/aura-app-dev
✅ Task definition registered: arn:aws:ecs:us-east-2:xxx:task-definition/aura-app-dev:x
✅ ECS service created: arn:aws:ecs:us-east-2:xxx:service/aura-dev-cluster/aura-app-service
✅ Health check passed: http://x.x.x.x:8000/health
✅ Health check passed: http://x.x.x.x:8001/health
✅ Deployment completed successfully!

Access URLs:
  API Gateway: http://x.x.x.x:8000
  Service Desk: http://x.x.x.x:8001
  API Documentation: http://x.x.x.x:8000/docs
```

### Knowledge Base Test Results
```bash
# Search articles should return:
{
  "message": "Knowledge base search completed",
  "data": {
    "articles": [...],
    "total_found": 5
  }
}

# Browse articles should return:
{
  "items": [...],
  "total": 25,
  "page": 1,
  "limit": 10
}
```

## Cleanup 🧹

### Remove Deployment
```bash
# Scale down to 0 tasks
aws ecs update-service --cluster aura-dev-cluster --service aura-app-service --desired-count 0

# Delete service
aws ecs delete-service --cluster aura-dev-cluster --service aura-app-service

# Clean up ALB (if created)
aws elbv2 delete-load-balancer --load-balancer-arn {ALB_ARN}
```

### Complete Cleanup Script
```bash
./deploy/scripts/cleanup-tasks.sh dev --force
```

## Cost Optimization 💰

### Current Solution Benefits
- **Saves $32/month** by using dynamic IPs instead of Elastic IPs
- **Optional ALB** - only create when needed for production
- **Efficient resource usage** - single task with multiple containers

### Monitoring Costs
```bash
# Check ECS costs
aws ce get-cost-and-usage --time-period Start=2025-01-01,End=2025-01-31 --granularity MONTHLY --metrics BlendedCost --group-by Type=DIMENSION,Key=SERVICE

# Monitor ALB costs (if enabled)
aws elbv2 describe-load-balancers --names aura-dev-alb
```

## Next Steps 🎯

1. **Test Knowledge Base**: Verify "search articles" and "browse articles" work
2. **Monitor Performance**: Check CloudWatch logs and metrics
3. **Scale if Needed**: Increase task count for higher load
4. **Add SSL**: Configure HTTPS with ALB and certificates
5. **Set up CI/CD**: Automate deployments with GitHub Actions

## Support 📞

For issues or questions:
1. Check the comprehensive documentation: `docs/AWS_Dynamic_IP_Solution.md`
2. Review CloudWatch logs: `/ecs/aura-app-dev`
3. Verify network connectivity and security groups
4. Test with curl commands provided above

The solution is designed to be resilient and self-healing, with automatic retry mechanisms and dynamic endpoint discovery to handle AWS's dynamic IP allocation.
