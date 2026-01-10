# Terraform Backend Setup Guide

You have two options for storing Terraform state:

## Option 1: Use Local State (Quick Start) ⚡

**Best for**: Quick testing, single developer, learning

**Steps:**
1. Comment out or remove the `backend "s3"` block in `provider.tf`
2. Run `terraform init` - state will be stored locally in `terraform.tfstate`

**Pros:**
- No setup required
- Works immediately
- Good for testing

**Cons:**
- Not suitable for teams
- No state locking
- Risk of losing state file

---

## Option 2: Use S3 Backend (Recommended for Production) 🏗️

**Best for**: Teams, CI/CD, production environments

### Step 1: Create S3 Bucket

**Option A: Use the automated script**
```bash
cd terraform
./setup-backend.sh
```

**Option B: Create manually**

```bash
# Set your preferred region (must match provider.tf backend region)
REGION="ap-northeast-1"  # or us-east-1, us-west-2, etc.
BUCKET_NAME="vk-terraform-state-bucket"

# Create bucket
if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
else
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION"
fi

# Enable versioning (allows recovery of previous state versions)
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --region "$REGION"

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }' \
    --region "$REGION"

# Block public access (security best practice)
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --region "$REGION"
```

### Step 2: Create DynamoDB Table for State Locking (Optional but Recommended)

State locking prevents concurrent modifications that could corrupt your state.

**Option A: Use the automated script**
```bash
cd terraform
./setup-dynamodb-lock.sh
```

**Option B: Create manually**

```bash
REGION="ap-northeast-1"  # Must match S3 bucket region
TABLE_NAME="terraform-state-lock"

aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION"

# Wait for table to be active
aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$REGION"
```

### Step 3: Update provider.tf

After creating the bucket and DynamoDB table, update `provider.tf`:

```hcl
backend "s3" {
  bucket         = "vk-terraform-state-bucket"
  key            = "ecs-fargate/terraform.tfstate"
  region         = "ap-northeast-1"  # Match your bucket region
  encrypt        = true
  dynamodb_table = "terraform-state-lock"  # Uncomment if using DynamoDB
}
```

### Step 4: Initialize Terraform

```bash
terraform init
```

---

## Required Permissions

Your AWS user/role needs these permissions:

### For S3 Bucket:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::vk-terraform-state-bucket",
        "arn:aws:s3:::vk-terraform-state-bucket/*"
      ]
    }
  ]
}
```

### For DynamoDB Table (if using state locking):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-state-lock"
    }
  ]
}
```

---

## Bucket Configuration Summary

✅ **Versioning**: Enabled (allows state recovery)  
✅ **Encryption**: AES256 server-side encryption  
✅ **Public Access**: Blocked (security)  
✅ **State Locking**: DynamoDB table (prevents corruption)

---

## Troubleshooting

### Error: "Bucket already exists"
- The bucket name must be globally unique
- Try a different name: `vk-terraform-state-bucket-<your-account-id>`

### Error: "Access Denied"
- Check your AWS credentials: `aws sts get-caller-identity`
- Verify IAM permissions for S3 and DynamoDB

### Error: "Region mismatch"
- Ensure the backend region in `provider.tf` matches where you created the bucket
- Check bucket region: `aws s3api get-bucket-location --bucket vk-terraform-state-bucket`

---

## Quick Start Recommendation

**For learning/testing**: Use **Option 1 (Local State)** - comment out the backend block

**For production/teams**: Use **Option 2 (S3 Backend)** - follow all steps above
