#!/bin/bash

# Cleanup script to delete CodeDeploy deployments, ECS tasks, and related resources
# before destroying Terraform infrastructure
# This prevents dependency issues during terraform destroy

set -e

# Configuration - Update these values to match your setup
AWS_REGION="${AWS_REGION:-us-east-1}"
ECS_CLUSTER="${ECS_CLUSTER:-nodejs-fargate-app-cluster}"
ECS_SERVICE="${ECS_SERVICE:-nodejs-fargate-app-service}"
CODEDEPLOY_APP="${CODEDEPLOY_APP:-nodejs-fargate-app-codedeploy-app}"
CODEDEPLOY_GROUP="${CODEDEPLOY_GROUP:-nodejs-fargate-app-deployment-group}"

echo "=== Cleanup Before Terraform Destroy ==="
echo "Region: $AWS_REGION"
echo "Cluster: $ECS_CLUSTER"
echo "Service: $ECS_SERVICE"
echo ""

# Step 1: Stop all running CodeDeploy deployments
echo "Step 1: Stopping all CodeDeploy deployments..."
DEPLOYMENTS=$(aws deploy list-deployments \
  --application-name "$CODEDEPLOY_APP" \
  --deployment-group-name "$CODEDEPLOY_GROUP" \
  --region "$AWS_REGION" \
  --query 'deployments' \
  --output text 2>/dev/null || echo "")

if [ -n "$DEPLOYMENTS" ]; then
  for DEPLOYMENT_ID in $DEPLOYMENTS; do
    STATUS=$(aws deploy get-deployment \
      --deployment-id "$DEPLOYMENT_ID" \
      --region "$AWS_REGION" \
      --query 'deploymentInfo.status' \
      --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$STATUS" != "STOPPED" ] && [ "$STATUS" != "SUCCEEDED" ] && [ "$STATUS" != "FAILED" ]; then
      echo "  Stopping deployment: $DEPLOYMENT_ID (Status: $STATUS)"
      aws deploy stop-deployment \
        --deployment-id "$DEPLOYMENT_ID" \
        --region "$AWS_REGION" 2>/dev/null || echo "    Already stopped or not found"
    else
      echo "  Deployment $DEPLOYMENT_ID already in final state: $STATUS"
    fi
  done
else
  echo "  No active deployments found"
fi
echo ""

# Step 2: Scale down ECS service to 0 tasks
echo "Step 2: Scaling down ECS service to 0 tasks..."
CURRENT_COUNT=$(aws ecs describe-services \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE" \
  --region "$AWS_REGION" \
  --query 'services[0].desiredCount' \
  --output text 2>/dev/null || echo "0")

if [ "$CURRENT_COUNT" != "0" ] && [ "$CURRENT_COUNT" != "None" ]; then
  echo "  Current desired count: $CURRENT_COUNT"
  echo "  Scaling down to 0..."
  aws ecs update-service \
    --cluster "$ECS_CLUSTER" \
    --service "$ECS_SERVICE" \
    --desired-count 0 \
    --region "$AWS_REGION" > /dev/null
  
  echo "  Waiting for tasks to stop..."
  aws ecs wait services-stable \
    --cluster "$ECS_CLUSTER" \
    --services "$ECS_SERVICE" \
    --region "$AWS_REGION" 2>/dev/null || echo "  Service scaled down"
else
  echo "  Service already scaled to 0"
fi
echo ""

# Step 3: Stop all running ECS tasks
echo "Step 3: Stopping all running ECS tasks..."
TASK_ARNS=$(aws ecs list-tasks \
  --cluster "$ECS_CLUSTER" \
  --service-name "$ECS_SERVICE" \
  --region "$AWS_REGION" \
  --query 'taskArns[]' \
  --output text 2>/dev/null || echo "")

if [ -n "$TASK_ARNS" ] && [ "$TASK_ARNS" != "None" ]; then
  for TASK_ARN in $TASK_ARNS; do
    echo "  Stopping task: $TASK_ARN"
    aws ecs stop-task \
      --cluster "$ECS_CLUSTER" \
      --task "$TASK_ARN" \
      --region "$AWS_REGION" > /dev/null 2>&1 || echo "    Task already stopped"
  done
  
  echo "  Waiting for tasks to stop..."
  sleep 10
else
  echo "  No running tasks found"
fi
echo ""

# Step 4: Delete ECS service (optional - Terraform will handle this)
echo "Step 4: Checking ECS service status..."
SERVICE_EXISTS=$(aws ecs describe-services \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE" \
  --region "$AWS_REGION" \
  --query 'services[0].status' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$SERVICE_EXISTS" != "NOT_FOUND" ] && [ "$SERVICE_EXISTS" != "None" ]; then
  echo "  Service exists. Terraform will delete it during destroy."
  echo "  If you want to delete it manually, uncomment the next section."
  # Uncomment to delete service manually:
  # echo "  Deleting ECS service..."
  # aws ecs delete-service \
  #   --cluster "$ECS_CLUSTER" \
  #   --service "$ECS_SERVICE" \
  #   --force \
  #   --region "$AWS_REGION" > /dev/null
else
  echo "  Service not found"
fi
echo ""

# Step 5: Delete CodeDeploy deployment group (optional - Terraform will handle this)
echo "Step 5: Checking CodeDeploy resources..."
APP_EXISTS=$(aws deploy get-application \
  --application-name "$CODEDEPLOY_APP" \
  --region "$AWS_REGION" \
  --query 'application.applicationName' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$APP_EXISTS" != "NOT_FOUND" ]; then
  echo "  CodeDeploy application exists. Terraform will delete it during destroy."
else
  echo "  CodeDeploy application not found"
fi
echo ""

# Step 6: Deregister old task definitions (optional cleanup)
echo "Step 6: Checking for old task definitions..."
TASK_DEFS=$(aws ecs list-task-definitions \
  --family-prefix nodejs-fargate-app-task \
  --region "$AWS_REGION" \
  --query 'taskDefinitionArns[]' \
  --output text 2>/dev/null || echo "")

if [ -n "$TASK_DEFS" ] && [ "$TASK_DEFS" != "None" ]; then
  echo "  Found task definitions. Note: AWS doesn't allow deleting task definitions."
  echo "  They will remain but won't cause issues. Count: $(echo $TASK_DEFS | wc -w)"
else
  echo "  No task definitions found"
fi
echo ""

echo "✅ Cleanup complete!"
echo ""
echo "You can now safely run:"
echo "  cd terraform"
echo "  terraform destroy"
echo ""
echo "Note: Some resources (like task definitions) cannot be deleted but won't cause issues."
