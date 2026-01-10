# Manual CodeDeploy Deployment Guide

This guide shows you how to manually create a CodeDeploy deployment from the command line.

## Quick Command

```bash
./scripts/manual-deploy.sh
```

## Step-by-Step Manual Commands

### 1. Set Environment Variables

```bash
export AWS_REGION="us-east-1"
export ECR_REPOSITORY="nodejs-fargate-app"
export ECS_CLUSTER="nodejs-fargate-app-cluster"
export ECS_SERVICE="nodejs-fargate-app-service"
export ECS_TASK_FAMILY="nodejs-fargate-app-task"
export CONTAINER_NAME="nodejs-fargate-app"
export CODEDEPLOY_APP="nodejs-fargate-app-codedeploy-app"
export CODEDEPLOY_GROUP="nodejs-fargate-app-deployment-group"
```

### 2. Get Latest Task Definition ARN

```bash
TASK_DEF_ARN=$(aws ecs describe-task-definition \
  --task-definition "$ECS_TASK_FAMILY" \
  --region "$AWS_REGION" \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "Task Definition: $TASK_DEF_ARN"
```

### 3. Get ECS Service Details

```bash
SERVICE_INFO=$(aws ecs describe-services \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE" \
  --region "$AWS_REGION" \
  --query 'services[0]')

SUBNET_1=$(echo $SERVICE_INFO | jq -r '.networkConfiguration.awsvpcConfiguration.subnets[0]')
SUBNET_2=$(echo $SERVICE_INFO | jq -r '.networkConfiguration.awsvpcConfiguration.subnets[1]')
SECURITY_GROUP=$(echo $SERVICE_INFO | jq -r '.networkConfiguration.awsvpcConfiguration.securityGroups[0]')
CONTAINER_NAME=$(echo $SERVICE_INFO | jq -r '.loadBalancers[0].containerName // "'"$CONTAINER_NAME"'"')
CONTAINER_PORT=$(echo $SERVICE_INFO | jq -r '.loadBalancers[0].containerPort // 3000')

echo "Subnet 1: $SUBNET_1"
echo "Subnet 2: $SUBNET_2"
echo "Security Group: $SECURITY_GROUP"
echo "Container Name: $CONTAINER_NAME"
echo "Container Port: $CONTAINER_PORT"
```

### 4. Generate AppSpec File

```bash
cat > appspec.yml <<EOF
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "$TASK_DEF_ARN"
        LoadBalancerInfo:
          ContainerName: "$CONTAINER_NAME"
          ContainerPort: $CONTAINER_PORT
        PlatformVersion: "LATEST"
        NetworkConfiguration:
          AwsvpcConfiguration:
            Subnets:
              - "$SUBNET_1"
              - "$SUBNET_2"
            SecurityGroups:
              - "$SECURITY_GROUP"
            AssignPublicIp: "DISABLED"
EOF

cat appspec.yml
```

### 5. Base64 Encode and Create Deployment YAML

```bash
# Base64 encode the AppSpec file
APPSPEC_CONTENT=$(cat appspec.yml | base64 -w 0)

# Create deployment YAML file
cat > deployment-input.yml <<EOF
applicationName: $CODEDEPLOY_APP
deploymentGroupName: $CODEDEPLOY_GROUP
revision:
  revisionType: AppSpecContent
  appSpecContent:
    content: $APPSPEC_CONTENT
EOF

cat deployment-input.yml
```

### 6. Create CodeDeploy Deployment

```bash
DEPLOYMENT_ID=$(aws deploy create-deployment \
  --cli-input-yaml file://deployment-input.yml \
  --region "$AWS_REGION" \
  --query 'deploymentId' \
  --output text)

echo "Deployment ID: $DEPLOYMENT_ID"
```

### 7. Monitor Deployment

```bash
# Check deployment status
aws deploy get-deployment \
  --deployment-id "$DEPLOYMENT_ID" \
  --region "$AWS_REGION" \
  --query 'deploymentInfo.status' \
  --output text

# Wait for deployment to complete
aws deploy wait deployment-successful \
  --deployment-id "$DEPLOYMENT_ID" \
  --region "$AWS_REGION"

# Get detailed deployment info
aws deploy get-deployment \
  --deployment-id "$DEPLOYMENT_ID" \
  --region "$AWS_REGION"
```

## All-in-One Command

```bash
# Set variables
export AWS_REGION="us-east-1"
export ECS_CLUSTER="nodejs-fargate-app-cluster"
export ECS_SERVICE="nodejs-fargate-app-service"
export ECS_TASK_FAMILY="nodejs-fargate-app-task"
export CONTAINER_NAME="nodejs-fargate-app"
export CODEDEPLOY_APP="nodejs-fargate-app-codedeploy-app"
export CODEDEPLOY_GROUP="nodejs-fargate-app-deployment-group"

# Get task definition
TASK_DEF_ARN=$(aws ecs describe-task-definition --task-definition "$ECS_TASK_FAMILY" --region "$AWS_REGION" --query 'taskDefinition.taskDefinitionArn' --output text)

# Get service info
SERVICE_INFO=$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" --region "$AWS_REGION" --query 'services[0]')
SUBNET_1=$(echo $SERVICE_INFO | jq -r '.networkConfiguration.awsvpcConfiguration.subnets[0]')
SUBNET_2=$(echo $SERVICE_INFO | jq -r '.networkConfiguration.awsvpcConfiguration.subnets[1]')
SECURITY_GROUP=$(echo $SERVICE_INFO | jq -r '.networkConfiguration.awsvpcConfiguration.securityGroups[0]')
CONTAINER_PORT=$(echo $SERVICE_INFO | jq -r '.loadBalancers[0].containerPort // 3000')

# Generate AppSpec
printf 'version: 0.0\nResources:\n  - TargetService:\n      Type: AWS::ECS::Service\n      Properties:\n        TaskDefinition: "%s"\n        LoadBalancerInfo:\n          ContainerName: "%s"\n          ContainerPort: %s\n        PlatformVersion: "LATEST"\n        NetworkConfiguration:\n          AwsvpcConfiguration:\n            Subnets:\n              - "%s"\n              - "%s"\n            SecurityGroups:\n              - "%s"\n            AssignPublicIp: "DISABLED"\n' "$TASK_DEF_ARN" "$CONTAINER_NAME" "$CONTAINER_PORT" "$SUBNET_1" "$SUBNET_2" "$SECURITY_GROUP" > appspec.yml

# Create deployment YAML
APPSPEC_CONTENT=$(cat appspec.yml | base64 -w 0)
cat > deployment-input.yml <<EOF
applicationName: $CODEDEPLOY_APP
deploymentGroupName: $CODEDEPLOY_GROUP
revision:
  revisionType: AppSpecContent
  appSpecContent:
    content: $APPSPEC_CONTENT
EOF

# Create deployment
DEPLOYMENT_ID=$(aws deploy create-deployment \
  --cli-input-yaml file://deployment-input.yml \
  --region "$AWS_REGION" \
  --query 'deploymentId' \
  --output text)

echo "Deployment ID: $DEPLOYMENT_ID"
```

## Troubleshooting

### Check Deployment Status

```bash
aws deploy get-deployment \
  --deployment-id "$DEPLOYMENT_ID" \
  --region "$AWS_REGION"
```

### List Recent Deployments

```bash
aws deploy list-deployments \
  --application-name "$CODEDEPLOY_APP" \
  --deployment-group-name "$CODEDEPLOY_GROUP" \
  --region "$AWS_REGION"
```

### View Deployment Events

```bash
aws deploy get-deployment \
  --deployment-id "$DEPLOYMENT_ID" \
  --region "$AWS_REGION" \
  --query 'deploymentInfo.deploymentOverview'
```

### Stop a Deployment

```bash
aws deploy stop-deployment \
  --deployment-id "$DEPLOYMENT_ID" \
  --region "$AWS_REGION"
```

## Prerequisites

- AWS CLI installed and configured
- `jq` installed (`brew install jq` on macOS)
- Proper AWS credentials with CodeDeploy permissions
- ECS cluster and service already created via Terraform
