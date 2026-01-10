#!/bin/bash

# Manual CodeDeploy Deployment Script
# This script allows you to manually deploy using AWS CLI

set -e

# Configuration - Update these values
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPOSITORY="${ECR_REPOSITORY:-nodejs-fargate-app}"
ECS_CLUSTER="${ECS_CLUSTER:-nodejs-fargate-app-cluster}"
ECS_SERVICE="${ECS_SERVICE:-nodejs-fargate-app-service}"
ECS_TASK_FAMILY="${ECS_TASK_FAMILY:-nodejs-fargate-app-task}"
CONTAINER_NAME="${CONTAINER_NAME:-nodejs-fargate-app}"
CODEDEPLOY_APP="${CODEDEPLOY_APP:-nodejs-fargate-app-codedeploy-app}"
CODEDEPLOY_GROUP="${CODEDEPLOY_GROUP:-nodejs-fargate-app-deployment-group}"

echo "=== Manual CodeDeploy Deployment ==="
echo "Region: $AWS_REGION"
echo "Cluster: $ECS_CLUSTER"
echo "Service: $ECS_SERVICE"
echo ""

# Step 1: Get the latest task definition
echo "Step 1: Getting latest task definition..."
TASK_DEF_ARN=$(aws ecs describe-task-definition \
  --task-definition "$ECS_TASK_FAMILY" \
  --region "$AWS_REGION" \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "Task Definition ARN: $TASK_DEF_ARN"
echo ""

# Step 2: Get ECS service details
echo "Step 2: Getting ECS service details..."
SERVICE_INFO=$(aws ecs describe-services \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE" \
  --region "$AWS_REGION" \
  --query 'services[0]')

SUBNET_1=$(echo $SERVICE_INFO | jq -r '.networkConfiguration.awsvpcConfiguration.subnets[0]')
SUBNET_2=$(echo $SERVICE_INFO | jq -r '.networkConfiguration.awsvpcConfiguration.subnets[1]')
SECURITY_GROUP=$(echo $SERVICE_INFO | jq -r '.networkConfiguration.awsvpcConfiguration.securityGroups[0]')
CONTAINER_NAME_FROM_SERVICE=$(echo $SERVICE_INFO | jq -r '.loadBalancers[0].containerName // "'"$CONTAINER_NAME"'"')
CONTAINER_PORT=$(echo $SERVICE_INFO | jq -r '.loadBalancers[0].containerPort // 3000')

echo "Subnet 1: $SUBNET_1"
echo "Subnet 2: $SUBNET_2"
echo "Security Group: $SECURITY_GROUP"
echo "Container Name: $CONTAINER_NAME_FROM_SERVICE"
echo "Container Port: $CONTAINER_PORT"
echo ""

# Step 3: Generate AppSpec file
echo "Step 3: Generating AppSpec file..."
printf 'version: 0.0\nResources:\n  - TargetService:\n      Type: AWS::ECS::Service\n      Properties:\n        TaskDefinition: "%s"\n        LoadBalancerInfo:\n          ContainerName: "%s"\n          ContainerPort: %s\n        PlatformVersion: "LATEST"\n        NetworkConfiguration:\n          AwsvpcConfiguration:\n            Subnets:\n              - "%s"\n              - "%s"\n            SecurityGroups:\n              - "%s"\n            AssignPublicIp: "DISABLED"\n' \
  "$TASK_DEF_ARN" \
  "$CONTAINER_NAME_FROM_SERVICE" \
  "$CONTAINER_PORT" \
  "$SUBNET_1" \
  "$SUBNET_2" \
  "$SECURITY_GROUP" > appspec.yml

echo "AppSpec file generated:"
cat appspec.yml
echo ""

# Step 4: Create deployment YAML with AppSpec content directly (no base64 encoding)
echo "Step 4: Creating deployment YAML..."
# Read AppSpec content and use YAML literal block scalar (|) for multiline content
APPSPEC_CONTENT=$(cat appspec.yml)

# Create deployment YAML with proper YAML multiline string formatting
cat > deployment-input.yml <<EOF
applicationName: $CODEDEPLOY_APP
deploymentGroupName: $CODEDEPLOY_GROUP
revision:
  revisionType: AppSpecContent
  appSpecContent:
    content: |
$(echo "$APPSPEC_CONTENT" | sed 's/^/      /')
EOF

echo "Deployment YAML created:"
cat deployment-input.yml
echo ""

# Step 5: Create CodeDeploy deployment
echo "Step 5: Creating CodeDeploy deployment..."
DEPLOYMENT_ID=$(aws deploy create-deployment \
  --cli-input-yaml file://deployment-input.yml \
  --region "$AWS_REGION" \
  --query 'deploymentId' \
  --output text)

echo "✅ Deployment created successfully!"
echo "Deployment ID: $DEPLOYMENT_ID"
echo ""
echo "To monitor the deployment, run:"
echo "  aws deploy get-deployment --deployment-id $DEPLOYMENT_ID --region $AWS_REGION"
echo ""
echo "To wait for completion, run:"
echo "  aws deploy wait deployment-successful --deployment-id $DEPLOYMENT_ID --region $AWS_REGION"
