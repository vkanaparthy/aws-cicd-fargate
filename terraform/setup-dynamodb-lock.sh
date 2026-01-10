#!/bin/bash

# Script to create DynamoDB table for Terraform state locking
# This prevents concurrent modifications to your Terraform state

set -e

TABLE_NAME="terraform-state-lock"
REGION="us-east-1"  # Should match your S3 bucket region
AWS_PROFILE="vk"     # AWS profile to use

echo "=========================================="
echo "Creating DynamoDB Table for State Locking"
echo "=========================================="
echo ""
echo "Table Name: $TABLE_NAME"
echo "Region: $REGION"
echo "AWS Profile: $AWS_PROFILE"
echo ""

# Check if table already exists
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" --profile "$AWS_PROFILE" 2>/dev/null; then
    echo "✓ Table already exists: $TABLE_NAME"
else
    echo "Creating DynamoDB table: $TABLE_NAME"
    
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION" \
        --profile "$AWS_PROFILE"
    
    echo "✓ Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$REGION" --profile "$AWS_PROFILE"
    echo "✓ Table created and active"
fi

echo ""
echo "=========================================="
echo "DynamoDB Table Setup Complete!"
echo "=========================================="
echo ""
echo "Table Name: $TABLE_NAME"
echo "Region: $REGION"
echo ""
echo "Update terraform/provider.tf to include:"
echo "  dynamodb_table = \"$TABLE_NAME\""
