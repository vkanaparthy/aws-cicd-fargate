# CodeDeploy Blue/Green Deployment Setup

This project uses AWS CodeDeploy for blue/green deployments on ECS Fargate, providing zero-downtime deployments with automatic rollback capabilities.

## Architecture Changes

### Removed Components
- ❌ **NAT Gateways** - Removed to reduce costs (~$32-64/month savings)
- ❌ **Internet Gateway routes from private subnets** - No longer needed

### Added Components
- ✅ **VPC Endpoints** - For AWS services (ECR, CloudWatch, S3)
- ✅ **CodeDeploy Application** - Manages blue/green deployments
- ✅ **CodeDeploy Deployment Group** - Configures deployment settings
- ✅ **Two Target Groups** - Blue (production) and Green (new deployment)
- ✅ **AppSpec File** - Defines deployment configuration

## How Blue/Green Deployment Works

### Deployment Flow

```
1. New Task Definition Created
   ↓
2. CodeDeploy Creates Green Environment
   ↓
3. Green Tasks Start with New Image
   ↓
4. Health Checks on Green Target Group
   ↓
5. Traffic Switched from Blue → Green
   ↓
6. Blue Tasks Terminated (after 5 min wait)
```

### Benefits

- ✅ **Zero Downtime**: Traffic switches only after green is healthy
- ✅ **Automatic Rollback**: If deployment fails, traffic stays on blue
- ✅ **Canary Testing**: Can test green environment before switching
- ✅ **Cost Savings**: No NAT Gateway costs (~$32-64/month)

## VPC Endpoints

Since NAT Gateways are removed, AWS services are accessed via VPC Endpoints:

### Interface Endpoints (PrivateLink)
- **ECR Docker API** (`com.amazonaws.region.ecr.dkr`) - Pull container images
- **ECR API** (`com.amazonaws.region.ecr.api`) - Image metadata
- **CloudWatch Logs** (`com.amazonaws.region.logs`) - Send application logs

### Gateway Endpoint
- **S3** (`com.amazonaws.region.s3`) - For any S3 access (no cost)

**Cost**: ~$7/month per Interface Endpoint (~$21/month total) vs ~$32-64/month for NAT Gateway

## CodeDeploy Configuration

### Deployment Group Settings

- **Blue Target Group**: Current production traffic
- **Green Target Group**: New deployment traffic
- **Deployment Ready**: Continue automatically after green is healthy
- **Termination**: Blue tasks terminated 5 minutes after successful switch
- **Auto Rollback**: Enabled on deployment failure

### AppSpec File

The `appspec.yml` file defines:
- Task definition to deploy
- Target group configuration
- Network configuration (subnets, security groups)
- Container name and port

## GitHub Actions Workflow

The workflow now:
1. Builds and pushes Docker image to ECR
2. Creates new task definition with updated image
3. Generates AppSpec file with service details
4. Creates CodeDeploy deployment
5. Waits for deployment completion

## Required IAM Permissions

Your GitHub Actions IAM user needs these additional permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:CreateDeployment",
        "codedeploy:GetDeployment",
        "codedeploy:GetDeploymentConfig",
        "codedeploy:GetApplication",
        "codedeploy:GetApplicationRevision",
        "codedeploy:RegisterApplicationRevision",
        "codedeploy:ListDeployments",
        "ecs:RegisterTaskDefinition",
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition"
      ],
      "Resource": "*"
    }
  ]
}
```

## Deployment Process

### Manual Deployment

```bash
# 1. Build and push image
docker build -t nodejs-fargate-app .
docker tag nodejs-fargate-app:latest <ECR_REPO>:latest
docker push <ECR_REPO>:latest

# 2. Create new task definition
aws ecs register-task-definition \
  --cli-input-json file://task-definition.json

# 3. Generate AppSpec file
./scripts/generate-appspec.sh

# 4. Update AppSpec with task definition ARN
# Edit appspec.yml and replace <TASK_DEFINITION>

# 5. Create CodeDeploy deployment
aws deploy create-deployment \
  --application-name nodejs-fargate-app-codedeploy-app \
  --deployment-group-name nodejs-fargate-app-deployment-group \
  --revision revisionType=AppSpecContent,appSpecContent={content="$(cat appspec.yml | base64)"}
```

### Automatic Deployment (GitHub Actions)

Simply push to the `main` branch - the workflow handles everything automatically.

## Monitoring Deployments

### View Deployment Status

```bash
# List recent deployments
aws deploy list-deployments \
  --application-name nodejs-fargate-app-codedeploy-app \
  --deployment-group-name nodejs-fargate-app-deployment-group

# Get deployment details
aws deploy get-deployment \
  --deployment-id <DEPLOYMENT_ID>
```

### CloudWatch Events

CodeDeploy sends events to CloudWatch Events for monitoring:
- `DEPLOYMENT_START`
- `DEPLOYMENT_SUCCESS`
- `DEPLOYMENT_FAILURE`

## Troubleshooting

### Issue: Deployment fails during green fleet provisioning

**Solution**: Check ECS service logs and ensure:
- Task definition is valid
- Image exists in ECR
- Security groups allow traffic
- Subnets have VPC endpoints configured

### Issue: Traffic not switching to green

**Solution**: Check target group health:
```bash
aws elbv2 describe-target-health \
  --target-group-arn <GREEN_TARGET_GROUP_ARN>
```

### Issue: VPC Endpoint connection issues

**Solution**: Verify security group allows HTTPS (port 443) from VPC CIDR:
```bash
aws ec2 describe-security-groups \
  --group-ids <VPC_ENDPOINT_SG_ID>
```

## Cost Comparison

| Component | Before | After | Savings |
|-----------|--------|-------|---------|
| NAT Gateway | $32-64/month | $0 | **$32-64/month** |
| VPC Endpoints | $0 | ~$21/month | -$21/month |
| **Total** | **$32-64/month** | **~$21/month** | **~$11-43/month** |

**Annual Savings**: ~$132-516/year

## Migration Notes

When migrating from existing deployment:

1. **First Deployment**: CodeDeploy will create the initial blue environment
2. **Subsequent Deployments**: Will use blue/green process
3. **Rollback**: If needed, manually switch target group back to blue

## Next Steps

- ✅ CodeDeploy configured
- ✅ VPC Endpoints added
- ✅ NAT Gateways removed
- ✅ GitHub Actions workflow updated
- ✅ AppSpec file created

Your infrastructure is now configured for zero-downtime blue/green deployments with CodeDeploy!
