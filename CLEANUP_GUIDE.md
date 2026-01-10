# Cleanup Guide - Before Terraform Destroy

This guide explains how to clean up CodeDeploy deployments, ECS tasks, and related resources before destroying Terraform infrastructure.

## Quick Cleanup Options

### Option 1: GitHub Actions Workflow (Recommended)

1. Go to **Actions** tab in GitHub
2. Select **"Cleanup Before Destroy"** workflow
3. Click **"Run workflow"**
4. Type `destroy` in the confirmation field
5. Click **"Run workflow"**

This will:
- ✅ Stop all CodeDeploy deployments
- ✅ Scale ECS service to 0
- ✅ Stop all running tasks
- ✅ Delete ECS service
- ✅ Optionally run Terraform destroy

### Option 2: Bash Script

Run the automated cleanup script:

```bash
./scripts/cleanup-before-destroy.sh
```

## Manual Cleanup Steps

### 1. Stop All CodeDeploy Deployments

```bash
export AWS_REGION="us-east-1"
export CODEDEPLOY_APP="nodejs-fargate-app-codedeploy-app"
export CODEDEPLOY_GROUP="nodejs-fargate-app-deployment-group"

# List all deployments
aws deploy list-deployments \
  --application-name "$CODEDEPLOY_APP" \
  --deployment-group-name "$CODEDEPLOY_GROUP" \
  --region "$AWS_REGION"

# Stop each active deployment
DEPLOYMENT_ID="<deployment-id>"
aws deploy stop-deployment \
  --deployment-id "$DEPLOYMENT_ID" \
  --region "$AWS_REGION"
```

### 2. Scale Down ECS Service to 0

```bash
export ECS_CLUSTER="nodejs-fargate-app-cluster"
export ECS_SERVICE="nodejs-fargate-app-service"

# Scale down to 0
aws ecs update-service \
  --cluster "$ECS_CLUSTER" \
  --service "$ECS_SERVICE" \
  --desired-count 0 \
  --region "$AWS_REGION"

# Wait for tasks to stop
aws ecs wait services-stable \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE" \
  --region "$AWS_REGION"
```

### 3. Stop All Running ECS Tasks

```bash
# List all tasks
TASK_ARNS=$(aws ecs list-tasks \
  --cluster "$ECS_CLUSTER" \
  --service-name "$ECS_SERVICE" \
  --region "$AWS_REGION" \
  --query 'taskArns[]' \
  --output text)

# Stop each task
for TASK_ARN in $TASK_ARNS; do
  aws ecs stop-task \
    --cluster "$ECS_CLUSTER" \
    --task "$TASK_ARN" \
    --region "$AWS_REGION"
done
```

### 4. Delete ECS Service (Optional)

**Note:** Terraform will handle this during destroy, but you can delete it manually if needed:

```bash
aws ecs delete-service \
  --cluster "$ECS_CLUSTER" \
  --service "$ECS_SERVICE" \
  --force \
  --region "$AWS_REGION"
```

### 5. Clean Up CodeDeploy Resources (Optional)

**Note:** Terraform will handle this during destroy:

```bash
# Delete deployment group (must delete deployments first)
aws deploy delete-deployment-group \
  --application-name "$CODEDEPLOY_APP" \
  --deployment-group-name "$CODEDEPLOY_GROUP" \
  --region "$AWS_REGION"

# Delete application
aws deploy delete-application \
  --application-name "$CODEDEPLOY_APP" \
  --region "$AWS_REGION"
```

## Complete Cleanup Script

```bash
#!/bin/bash
set -e

export AWS_REGION="us-east-1"
export ECS_CLUSTER="nodejs-fargate-app-cluster"
export ECS_SERVICE="nodejs-fargate-app-service"
export CODEDEPLOY_APP="nodejs-fargate-app-codedeploy-app"
export CODEDEPLOY_GROUP="nodejs-fargate-app-deployment-group"

# Stop deployments
echo "Stopping deployments..."
DEPLOYMENTS=$(aws deploy list-deployments \
  --application-name "$CODEDEPLOY_APP" \
  --deployment-group-name "$CODEDEPLOY_GROUP" \
  --region "$AWS_REGION" \
  --query 'deployments' \
  --output text 2>/dev/null || echo "")

for DEPLOYMENT_ID in $DEPLOYMENTS; do
  STATUS=$(aws deploy get-deployment \
    --deployment-id "$DEPLOYMENT_ID" \
    --region "$AWS_REGION" \
    --query 'deploymentInfo.status' \
    --output text 2>/dev/null || echo "NOT_FOUND")
  
  if [ "$STATUS" = "InProgress" ] || [ "$STATUS" = "Ready" ]; then
    aws deploy stop-deployment \
      --deployment-id "$DEPLOYMENT_ID" \
      --region "$AWS_REGION" 2>/dev/null || true
  fi
done

# Scale down service
echo "Scaling down service..."
aws ecs update-service \
  --cluster "$ECS_CLUSTER" \
  --service "$ECS_SERVICE" \
  --desired-count 0 \
  --region "$AWS_REGION" > /dev/null

# Wait for tasks to stop
echo "Waiting for tasks to stop..."
sleep 30

# Stop all tasks
echo "Stopping tasks..."
TASK_ARNS=$(aws ecs list-tasks \
  --cluster "$ECS_CLUSTER" \
  --service-name "$ECS_SERVICE" \
  --region "$AWS_REGION" \
  --query 'taskArns[]' \
  --output text 2>/dev/null || echo "")

for TASK_ARN in $TASK_ARNS; do
  aws ecs stop-task \
    --cluster "$ECS_CLUSTER" \
    --task "$TASK_ARN" \
    --region "$AWS_REGION" > /dev/null 2>&1 || true
done

echo "Cleanup complete! You can now run terraform destroy"
```

## Destroy Terraform Infrastructure

After cleanup, destroy the infrastructure:

```bash
cd terraform

# Review what will be destroyed
terraform plan -destroy

# Destroy infrastructure
terraform destroy
```

## Resources That Cannot Be Deleted

Some resources cannot be deleted and will remain:

1. **Task Definitions** - AWS doesn't allow deletion of task definitions
   - They remain but don't cause issues
   - They don't incur costs

2. **CloudWatch Logs** - Log groups remain but can be deleted manually:
   ```bash
   aws logs delete-log-group \
     --log-group-name /ecs/nodejs-fargate-app \
     --region us-east-1
   ```

3. **ECR Images** - Container images remain in ECR
   - Delete manually if needed:
   ```bash
   aws ecr batch-delete-image \
     --repository-name nodejs-fargate-app \
     --image-ids imageTag=latest \
     --region us-east-1
   ```

## Troubleshooting

### Error: Cannot delete service with running tasks

**Solution:** Scale down to 0 and wait, or use `--force` flag:
```bash
aws ecs delete-service \
  --cluster "$ECS_CLUSTER" \
  --service "$ECS_SERVICE" \
  --force \
  --region "$AWS_REGION"
```

### Error: Deployment in progress

**Solution:** Stop the deployment first:
```bash
aws deploy stop-deployment \
  --deployment-id "$DEPLOYMENT_ID" \
  --region "$AWS_REGION"
```

### Error: Cannot delete deployment group with active deployments

**Solution:** Wait for deployments to complete or stop them:
```bash
# Wait for deployment
aws deploy wait deployment-successful \
  --deployment-id "$DEPLOYMENT_ID" \
  --region "$AWS_REGION"
```

## Order of Operations

1. ✅ Stop all CodeDeploy deployments
2. ✅ Scale ECS service to 0
3. ✅ Stop all running tasks
4. ✅ Wait for resources to stabilize
5. ✅ Run `terraform destroy`

## Verification

After cleanup, verify resources are stopped:

```bash
# Check service count
aws ecs describe-services \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE" \
  --region "$AWS_REGION" \
  --query 'services[0].desiredCount'

# Check running tasks
aws ecs list-tasks \
  --cluster "$ECS_CLUSTER" \
  --service-name "$ECS_SERVICE" \
  --region "$AWS_REGION"

# Check deployments
aws deploy list-deployments \
  --application-name "$CODEDEPLOY_APP" \
  --deployment-group-name "$CODEDEPLOY_GROUP" \
  --region "$AWS_REGION"
```
