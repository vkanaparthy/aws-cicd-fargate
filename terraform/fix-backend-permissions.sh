#!/bin/bash

# Script to fix S3 backend permissions for Terraform
# This ensures the AWS profile has proper permissions to access the bucket

set -e

BUCKET_NAME="${1:-vk-terraform-state-733bf40e}"  # Use provided bucket name or default
AWS_PROFILE="vk"
REGION="us-east-1"

echo "=========================================="
echo "Fixing S3 Backend Permissions"
echo "=========================================="
echo ""
echo "Bucket Name: $BUCKET_NAME"
echo "AWS Profile: $AWS_PROFILE"
echo "Region: $REGION"
echo ""

# Get the AWS account ID and user/role ARN
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)
CURRENT_USER_ARN=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Arn --output text)

echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "Current User/Role: $CURRENT_USER_ARN"
echo ""

# Create bucket policy that allows the current user to access the bucket
BUCKET_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformStateAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "$CURRENT_USER_ARN"
      },
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::$BUCKET_NAME",
        "arn:aws:s3:::$BUCKET_NAME/*"
      ]
    }
  ]
}
EOF
)

echo "Applying bucket policy..."
echo "$BUCKET_POLICY" > /tmp/bucket-policy.json

aws s3api put-bucket-policy \
    --bucket "$BUCKET_NAME" \
    --policy file:///tmp/bucket-policy.json \
    --profile "$AWS_PROFILE" \
    --region "$REGION"

echo "✓ Bucket policy applied successfully"
echo ""

# Verify access
echo "Verifying access..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" --region "$REGION" 2>/dev/null; then
    echo "✓ Bucket access verified"
else
    echo "✗ Warning: Could not verify bucket access"
fi

echo ""
echo "=========================================="
echo "Permissions Fixed!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Make sure AWS_PROFILE is set: export AWS_PROFILE=vk"
echo "2. Run: terraform init"
echo ""
echo "If you still get access denied errors:"
echo "1. Check your IAM user has S3 permissions"
echo "2. Verify the profile name matches: aws configure list --profile vk"
echo ""

# Cleanup
rm -f /tmp/bucket-policy.json
