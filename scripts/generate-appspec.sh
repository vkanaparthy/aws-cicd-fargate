#!/bin/bash

# Script to generate AppSpec file for CodeDeploy
# This script extracts ECS service information and creates the AppSpec file

set -e

CLUSTER_NAME="${1:-nodejs-fargate-app-cluster}"
SERVICE_NAME="${2:-nodejs-fargate-app-service}"
AWS_REGION="${3:-us-east-1}"

echo "Generating AppSpec file for CodeDeploy..."
echo "Cluster: $CLUSTER_NAME"
echo "Service: $SERVICE_NAME"
echo "Region: $AWS_REGION"
echo ""

# Get ECS service details
SERVICE_INFO=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$AWS_REGION" \
  --query 'services[0]')

if [ "$(echo $SERVICE_INFO | jq -r '.status')" != "ACTIVE" ]; then
  echo "Error: ECS service not found or not active"
  exit 1
fi

SUBNET_1=$(echo $SERVICE_INFO | jq -r '.networkConfiguration.awsvpcConfiguration.subnets[0]')
SUBNET_2=$(echo $SERVICE_INFO | jq -r '.networkConfiguration.awsvpcConfiguration.subnets[1]')
SECURITY_GROUP=$(echo $SERVICE_INFO | jq -r '.networkConfiguration.awsvpcConfiguration.securityGroups[0]')
CONTAINER_NAME=$(echo $SERVICE_INFO | jq -r '.loadBalancers[0].containerName')
CONTAINER_PORT=$(echo $SERVICE_INFO | jq -r '.loadBalancers[0].containerPort')

echo "Extracted information:"
echo "  Subnet 1: $SUBNET_1"
echo "  Subnet 2: $SUBNET_2"
echo "  Security Group: $SECURITY_GROUP"
echo "  Container Name: $CONTAINER_NAME"
echo "  Container Port: $CONTAINER_PORT"
echo ""

# Create AppSpec file
cat > appspec.yml <<EOF
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "<TASK_DEFINITION>"
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

echo "AppSpec file generated: appspec.yml"
echo ""
echo "Note: Replace <TASK_DEFINITION> with the actual task definition ARN during deployment"
