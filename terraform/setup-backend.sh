#!/bin/bash

# Script to create S3 bucket for Terraform state backend
# This sets up the bucket with proper permissions and versioning

set -e

REGION="us-east-1"  # Change this to your preferred region
AWS_PROFILE="vk"    # AWS profile to use

# Generate unique bucket name with random suffix
# S3 bucket names must be globally unique across all AWS accounts
# If you want a specific name, set BUCKET_NAME directly below
RANDOM_SUFFIX=$(openssl rand -hex 4)
BUCKET_NAME="vk-terraform-state-${RANDOM_SUFFIX}"

# Alternative: Use a custom name (uncomment and modify if preferred)
# BUCKET_NAME="vk-terraform-state-bucket-custom-name"

echo "=========================================="
echo "Creating S3 Bucket for Terraform State"
echo "=========================================="
echo ""
echo "Bucket Name: $BUCKET_NAME"
echo "Region: $REGION"
echo "AWS Profile: $AWS_PROFILE"
echo "Random Suffix: $RANDOM_SUFFIX"
echo ""
echo "Note: If this bucket name is taken, the script will try to create it."
echo "If it fails, edit the script and set a custom BUCKET_NAME."
echo ""

# Check if bucket already exists
if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" --profile "$AWS_PROFILE" 2>/dev/null; then
    echo "✓ Bucket already exists: $BUCKET_NAME"
else
    echo "Creating bucket: $BUCKET_NAME"
    
    # Create bucket
    if [ "$REGION" = "us-east-1" ]; then
        # us-east-1 doesn't need LocationConstraint
        CREATE_OUTPUT=$(aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --profile "$AWS_PROFILE" 2>&1)
        CREATE_EXIT_CODE=$?
        
        if [ $CREATE_EXIT_CODE -eq 0 ]; then
            echo "✓ Bucket created successfully"
        else
            echo ""
            echo "✗ Error creating bucket: $BUCKET_NAME"
            echo "$CREATE_OUTPUT" | grep -q "BucketAlreadyExists" && {
                echo "Error: Bucket name is already taken (globally unique required)"
            } || {
                echo "Error details:"
                echo "$CREATE_OUTPUT"
            }
            echo ""
            echo "Please:"
            echo "1. Edit this script and set a custom BUCKET_NAME, OR"
            echo "2. Run the script again (it will generate a new random name)"
            echo ""
            exit 1
        fi
    else
        # Other regions need LocationConstraint
        CREATE_OUTPUT=$(aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION" \
            --profile "$AWS_PROFILE" 2>&1)
        CREATE_EXIT_CODE=$?
        
        if [ $CREATE_EXIT_CODE -eq 0 ]; then
            echo "✓ Bucket created successfully"
        else
            echo ""
            echo "✗ Error creating bucket: $BUCKET_NAME"
            echo "$CREATE_OUTPUT" | grep -q "BucketAlreadyExists" && {
                echo "Error: Bucket name is already taken (globally unique required)"
            } || {
                echo "Error details:"
                echo "$CREATE_OUTPUT"
            }
            echo ""
            echo "Please:"
            echo "1. Edit this script and set a custom BUCKET_NAME, OR"
            echo "2. Run the script again (it will generate a new random name)"
            echo ""
            exit 1
        fi
    fi
fi

# Enable versioning
echo "Enabling versioning..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --region "$REGION" \
    --profile "$AWS_PROFILE"
echo "✓ Versioning enabled"

# Enable server-side encryption
echo "Enabling server-side encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }' \
    --region "$REGION" \
    --profile "$AWS_PROFILE"
echo "✓ Encryption enabled"

# Block public access
echo "Blocking public access..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --region "$REGION" \
    --profile "$AWS_PROFILE"
echo "✓ Public access blocked"

# Create bucket policy for Terraform state locking (DynamoDB will be needed for state locking)
echo ""
echo "=========================================="
echo "Bucket Setup Complete!"
echo "=========================================="
echo ""
echo "Bucket Name: $BUCKET_NAME"
echo "Region: $REGION"
echo ""
echo "Next steps:"
echo "1. Update terraform/provider.tf with the bucket name: $BUCKET_NAME"
echo "2. Update terraform/provider.tf with the region: $REGION"
echo "3. Run: terraform init"
echo ""
echo "Optional: For state locking, you'll also need a DynamoDB table."
echo "Run: ./setup-dynamodb-lock.sh"
echo ""
echo "IMPORTANT: Copy this bucket name to provider.tf:"
echo "  bucket = \"$BUCKET_NAME\""
