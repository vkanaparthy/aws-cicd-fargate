# Quick Start Guide - Step by Step

This guide will walk you through deploying the Node.js application to AWS ECS Fargate.

## Prerequisites Check

Before starting, ensure you have the following installed and configured:

### 1. Check Prerequisites

```bash
# Check Node.js version (should be >= 18.0.0)
node --version

# Check npm version
npm --version

# Check Docker installation
docker --version

# Check AWS CLI installation
aws --version

# Check Terraform installation
terraform --version

# Verify AWS credentials are configured
aws sts get-caller-identity
```

If any of these fail, install the missing tools:
- **Node.js**: Download from https://nodejs.org/
- **Docker**: Download from https://www.docker.com/products/docker-desktop
- **AWS CLI**: `brew install awscli` (macOS) or follow https://aws.amazon.com/cli/
- **Terraform**: `brew install terraform` (macOS) or follow https://www.terraform.io/downloads

### 2. Configure AWS Credentials

If AWS CLI is not configured:

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region (e.g., us-east-1)
# Enter default output format (json)
```

---

## Step 1: Install Dependencies

```bash
# Navigate to project directory
cd aws-cicd-fargate

# Install Node.js dependencies
npm install
```

**Expected Output**: Dependencies installed successfully.

---

## Step 2: Test Application Locally

```bash
# Start the application
npm start
```

**Expected Output**: 
```
Server is running on port 3000
Environment: production
```

**Test the application:**
- Open browser: http://localhost:3000
- Check health endpoint: http://localhost:3000/health

You should see JSON responses. Press `Ctrl+C` to stop the server.

---

## Step 3: Build and Test Docker Image Locally

```bash
# Build the Docker image
docker build -t nodejs-fargate-app:local .

# Run the container locally
docker run -d -p 3000:3000 --name test-app nodejs-fargate-app:local

# Test the application
curl http://localhost:3000
curl http://localhost:3000/health

# Stop and remove the container
docker stop test-app
docker rm test-app
```

**Expected Output**: Application responds correctly in Docker container.

---

## Step 4: Configure Terraform Variables

```bash
# Navigate to terraform directory
cd terraform

# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your preferred editor
# You can use nano, vim, or your preferred editor
nano terraform.tfvars
```

**Recommended values for terraform.tfvars:**
```hcl
aws_region       = "us-east-1"        # Change to your preferred region
app_name         = "nodejs-fargate-app"
environment      = "production"
vpc_cidr         = "10.0.0.0/16"      # Ensure this doesn't conflict with existing VPCs
container_port   = 3000
container_cpu    = 256                 # 0.25 vCPU
container_memory = 512                 # 512 MB
desired_count    = 1                   # Start with 1 task
min_capacity     = 1
max_capacity     = 10
```

**Important**: 
- Choose a region close to you (e.g., `us-east-1`, `us-west-2`, `eu-west-1`)
- Ensure the VPC CIDR doesn't conflict with existing VPCs in your account
- For testing, you can use smaller values (256 CPU, 512 MB memory)

---

## Step 5: Initialize Terraform

```bash
# Make sure you're in the terraform directory
cd terraform

# Initialize Terraform (downloads providers)
terraform init
```

**Expected Output**: 
```
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully initialized!
```

---

## Step 6: Review Terraform Plan

```bash
# Review what will be created (this doesn't create anything yet)
terraform plan
```

**What to expect:**
- This will show you all resources that will be created
- Review the output carefully
- Look for any errors or warnings
- The plan should show ~20+ resources to be created

**Common issues:**
- If you see region errors, check your `terraform.tfvars`
- If you see permission errors, verify your AWS credentials
- If you see VPC CIDR conflicts, change the `vpc_cidr` value

---

## Step 7: Deploy Infrastructure

```bash
# Apply the Terraform configuration
terraform apply

# Terraform will ask for confirmation
# Type: yes
```

**This will take approximately 10-15 minutes** to create:
- VPC and networking components
- Load balancer
- ECS cluster
- ECR repository
- IAM roles
- Security groups
- And more...

**Expected Output**: 
```
Apply complete! Resources: 20 added, 0 changed, 0 destroyed.
```

**Save the outputs** - You'll need these values:
```bash
# Get the outputs
terraform output

# Save important values:
terraform output -raw ecr_repository_url
terraform output -raw ecs_cluster_name
terraform output -raw ecs_service_name
terraform output -raw application_url
```

---

## Step 8: Build and Push Docker Image to ECR

```bash
# Get the ECR repository URL from Terraform output
ECR_REPO=$(terraform output -raw ecr_repository_url)
AWS_REGION=$(terraform output -raw aws_region || echo "us-east-1")

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO

# Build the image
docker build -t nodejs-fargate-app .

# Tag the image
docker tag nodejs-fargate-app:latest $ECR_REPO:latest

# Push the image
docker push $ECR_REPO:latest
```

**Expected Output**: Image pushed successfully to ECR.

---

## Step 9: Update ECS Service with Initial Image

```bash
# Get values from Terraform outputs
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
SERVICE_NAME=$(terraform output -raw ecs_service_name)

# Force a new deployment (this will use the image we just pushed)
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --force-new-deployment \
  --region $(terraform output -raw aws_region || echo "us-east-1")
```

**Wait for deployment** (check status):
```bash
# Watch the service deployment
aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --query 'services[0].deployments[0].status' \
  --region $(terraform output -raw aws_region || echo "us-east-1")
```

Wait until you see `PRIMARY` status.

---

## Step 10: Get Application URL and Test

```bash
# Get the application URL
terraform output application_url

# Or get ALB DNS name
terraform output alb_dns_name
```

**Test the application:**
```bash
# Get the URL
APP_URL=$(terraform output -raw application_url)

# Test the main endpoint
curl $APP_URL

# Test the health endpoint
curl $APP_URL/health
```

**Expected Response:**
```json
{
  "message": "Hello from AWS ECS Fargate!",
  "version": "1.0.0",
  "environment": "production",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

**Open in browser**: Copy the URL and open it in your browser.

---

## Step 11: Set Up GitHub Actions CI/CD

### 11.1: Push Code to GitHub

```bash
# Navigate back to project root
cd ..

# Initialize git (if not already done)
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit: ECS Fargate CI/CD setup"

# Add your GitHub repository as remote
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git

# Push to GitHub
git push -u origin main
```

### 11.2: Configure GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add the following secrets:

   **Secret 1: AWS_ACCESS_KEY_ID**
   - Name: `AWS_ACCESS_KEY_ID`
   - Value: Your AWS Access Key ID

   **Secret 2: AWS_SECRET_ACCESS_KEY**
   - Name: `AWS_SECRET_ACCESS_KEY`
   - Value: Your AWS Secret Access Key

### 11.3: Update GitHub Actions Workflow

```bash
# Edit the workflow file
nano .github/workflows/deploy.yml
```

Update these environment variables to match your Terraform outputs:
```yaml
env:
  AWS_REGION: us-east-1                    # Your AWS region
  ECR_REPOSITORY: nodejs-fargate-app      # Your ECR repo name
  ECS_SERVICE: nodejs-fargate-app-service # Your ECS service name
  ECS_CLUSTER: nodejs-fargate-app-cluster # Your ECS cluster name
  ECS_TASK_FAMILY: nodejs-fargate-app-task # Your task definition family
  CONTAINER_NAME: nodejs-fargate-app       # Your container name
```

**Get these values from Terraform:**
```bash
cd terraform
terraform output
```

### 11.4: Commit and Push Changes

```bash
cd ..
git add .github/workflows/deploy.yml
git commit -m "Update GitHub Actions workflow with correct values"
git push origin main
```

### 11.5: Monitor GitHub Actions

1. Go to your GitHub repository
2. Click on **Actions** tab
3. You should see a workflow run starting
4. Click on it to see the progress
5. Wait for it to complete (should take ~5-10 minutes)

---

## Step 12: Verify CI/CD Pipeline

After the GitHub Actions workflow completes:

```bash
# Get the application URL
cd terraform
terraform output application_url

# Test the application
curl $(terraform output -raw application_url)
```

The application should be running with the latest code from your GitHub repository!

---

## Step 13: Test CI/CD Pipeline

Make a small change to test the pipeline:

```bash
# Edit the app.js file
nano app.js

# Change the message (line ~12)
# From: "Hello from AWS ECS Fargate!"
# To: "Hello from AWS ECS Fargate - Updated!"

# Commit and push
git add app.js
git commit -m "Test CI/CD pipeline"
git push origin main
```

**Monitor GitHub Actions:**
- Go to GitHub → Actions tab
- Watch the workflow run
- Wait for deployment to complete (~5-10 minutes)

**Verify the change:**
```bash
curl $(cd terraform && terraform output -raw application_url)
```

You should see your updated message!

---

## Troubleshooting

### Issue: Terraform apply fails

**Check:**
- AWS credentials are configured correctly
- You have necessary permissions in AWS
- Region is correct
- VPC CIDR doesn't conflict

**Solution:**
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check IAM permissions (you need: EC2, ECS, VPC, IAM, ECR, CloudWatch permissions)
```

### Issue: Docker push fails

**Check:**
- ECR repository exists
- You're logged into ECR
- Image is tagged correctly

**Solution:**
```bash
# Re-login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ECR_REPO_URL
```

### Issue: ECS service not starting

**Check:**
- Task definition is correct
- Image exists in ECR
- Security groups allow traffic
- Subnets are configured correctly

**Solution:**
```bash
# Check ECS service events
aws ecs describe-services \
  --cluster YOUR_CLUSTER_NAME \
  --services YOUR_SERVICE_NAME \
  --query 'services[0].events[:5]'

# Check CloudWatch logs
aws logs tail /ecs/nodejs-fargate-app --follow
```

### Issue: Application not accessible

**Check:**
- ALB target group health
- Security group rules
- ECS tasks are running

**Solution:**
```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)

# Check ECS tasks
aws ecs list-tasks --cluster YOUR_CLUSTER_NAME
```

### Issue: GitHub Actions workflow fails

**Check:**
- GitHub secrets are set correctly
- Workflow file has correct values
- AWS credentials have necessary permissions

**Solution:**
- Check GitHub Actions logs for specific errors
- Verify secrets are set correctly
- Ensure IAM user has ECS, ECR, and CloudWatch permissions

---

## Cleanup (When Done Testing)

**Warning**: This will delete ALL resources and incur costs if left running!

```bash
cd terraform

# Review what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Type: yes when prompted
```

**Note**: This will delete:
- All infrastructure
- ECR images
- CloudWatch logs
- Everything created by Terraform

---

## Next Steps

1. **Add HTTPS**: Configure SSL certificate for the ALB
2. **Set up monitoring**: Add CloudWatch alarms
3. **Add database**: Connect to RDS or DynamoDB
4. **Multiple environments**: Create dev/staging/prod environments
5. **Blue/Green deployments**: Implement zero-downtime deployments
6. **Cost optimization**: Review and optimize resource sizes

---

## Useful Commands Reference

```bash
# View Terraform outputs
cd terraform && terraform output

# View ECS service status
aws ecs describe-services --cluster YOUR_CLUSTER --services YOUR_SERVICE

# View CloudWatch logs
aws logs tail /ecs/nodejs-fargate-app --follow

# View running tasks
aws ecs list-tasks --cluster YOUR_CLUSTER

# Force new deployment
aws ecs update-service --cluster YOUR_CLUSTER --service YOUR_SERVICE --force-new-deployment

# View ALB target health
aws elbv2 describe-target-health --target-group-arn YOUR_TG_ARN
```

---

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review CloudWatch logs
3. Check GitHub Actions logs
4. Verify all configuration values match Terraform outputs

Happy deploying! 🚀
