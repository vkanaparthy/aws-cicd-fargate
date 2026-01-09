# AWS ECS Fargate CI/CD Pipeline

This project demonstrates a complete CI/CD pipeline for deploying a Node.js application to AWS ECS Fargate using GitHub Actions, Terraform, and Docker.

## Architecture

- **Application**: Node.js Express application
- **Container**: Docker container running on AWS ECS Fargate
- **Infrastructure**: Provisioned using Terraform
- **CI/CD**: GitHub Actions workflow
- **Load Balancing**: Application Load Balancer (ALB)
- **Registry**: Amazon ECR (Elastic Container Registry)
- **Logging**: CloudWatch Logs
- **Networking**: VPC with public and private subnets

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI installed and configured
- Terraform >= 1.0 installed
- Docker installed
- Node.js >= 18.0.0 installed
- GitHub repository (for CI/CD pipeline)
- GitHub Actions secrets configured

## Project Structure

```
.
├── app.js                      # Node.js Express application
├── package.json                # Node.js dependencies
├── Dockerfile                  # Docker image definition
├── ecs-task-definition.json    # ECS task definition template
├── .dockerignore              # Files to exclude from Docker build
├── .gitignore                 # Git ignore file
├── .github/
│   └── workflows/
│       └── deploy.yml         # GitHub Actions CI/CD workflow
├── terraform/
│   ├── main.tf                # Main Terraform configuration
│   ├── variables.tf           # Terraform variables
│   ├── outputs.tf             # Terraform outputs
│   ├── provider.tf            # AWS provider configuration
│   └── terraform.tfvars.example # Example variables file
└── scripts/
    └── update-task-definition.sh # Helper script for task definition updates
```

## Setup Instructions

### 1. Clone and Install Dependencies

```bash
git clone <your-repo-url>
cd aws-cicd-fargate
npm install
```

### 2. Test Locally

```bash
npm start
# Application will be available at http://localhost:3000
```

### 3. Configure Terraform

1. Navigate to the terraform directory:
```bash
cd terraform
```

2. Copy the example variables file:
```bash
cp terraform.tfvars.example terraform.tfvars
```

3. Edit `terraform.tfvars` with your desired values:
```hcl
aws_region       = "us-east-1"
app_name         = "nodejs-fargate-app"
environment      = "production"
vpc_cidr         = "10.0.0.0/16"
container_port   = 3000
container_cpu    = 256
container_memory = 512
desired_count    = 1
min_capacity     = 1
max_capacity     = 10
```

4. (Optional) Configure S3 backend for Terraform state:
   - Edit `provider.tf` and uncomment the backend configuration
   - Create an S3 bucket for storing Terraform state

### 4. Deploy Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Review the planned changes
terraform plan

# Apply the infrastructure
terraform apply
```

This will create:
- VPC with public and private subnets
- NAT Gateways for private subnet internet access
- Application Load Balancer
- ECS Cluster
- ECR Repository
- ECS Task Definition
- ECS Service
- CloudWatch Log Group
- IAM Roles
- Security Groups
- Auto Scaling configuration

After deployment, note the outputs:
- `alb_dns_name`: URL to access your application
- `ecr_repository_url`: ECR repository URL for pushing images
- `ecs_cluster_name`: ECS cluster name
- `ecs_service_name`: ECS service name

### 5. Build and Push Docker Image Manually (Optional)

```bash
# Get ECR repository URL from Terraform output
ECR_REPO=$(terraform -chdir=terraform output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO

# Build the image
docker build -t nodejs-fargate-app .

# Tag the image
docker tag nodejs-fargate-app:latest $ECR_REPO:latest

# Push the image
docker push $ECR_REPO:latest
```

### 6. Configure GitHub Actions

1. Go to your GitHub repository settings
2. Navigate to **Settings > Secrets and variables > Actions**
3. Add the following secrets:
   - `AWS_ACCESS_KEY_ID`: Your AWS access key
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key

4. Update the `.github/workflows/deploy.yml` file with your values:
   - `AWS_REGION`: Your AWS region
   - `ECR_REPOSITORY`: Your ECR repository name (from Terraform output)
   - `ECS_SERVICE`: Your ECS service name (from Terraform output)
   - `ECS_CLUSTER`: Your ECS cluster name (from Terraform output)

### 7. Update ECS Task Definition

Before the first deployment, you need to update the `ecs-task-definition.json` file:

1. Get the ECR repository URL and region from Terraform outputs
2. Update the following placeholders in `ecs-task-definition.json`:
   - `YOUR_ACCOUNT_ID`: Your AWS account ID
   - `YOUR_REGION`: Your AWS region (e.g., us-east-1)

Example:
```json
"image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/nodejs-fargate-app:latest"
```

Alternatively, if you're using Terraform-managed task definitions, the GitHub Actions workflow will use the Terraform-created task definition automatically.

### 8. Deploy via GitHub Actions

1. Commit and push your changes to the `main` branch:
```bash
git add .
git commit -m "Initial commit"
git push origin main
```

2. The GitHub Actions workflow will automatically:
   - Build the Docker image
   - Push it to ECR
   - Update the ECS task definition
   - Deploy to ECS Fargate

3. Monitor the deployment in the GitHub Actions tab

### 9. Access Your Application

After deployment, get your application URL:
```bash
cd terraform
terraform output application_url
```

Or access it directly using the ALB DNS name from Terraform outputs.

## Manual Deployment

If you need to deploy manually:

```bash
# Build and push image (see step 5)

# Update ECS service to force new deployment
aws ecs update-service \
  --cluster nodejs-fargate-cluster \
  --service nodejs-fargate-service \
  --force-new-deployment \
  --region us-east-1
```

## Monitoring

- **CloudWatch Logs**: View application logs at `/ecs/nodejs-fargate-app`
- **ECS Console**: Monitor service health and task status
- **ALB**: Check target health and request metrics
- **CloudWatch Metrics**: CPU, memory, and request metrics

## Health Checks

The application includes a health check endpoint at `/health` that returns:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

## Auto Scaling

The infrastructure is configured with auto-scaling based on:
- CPU utilization (target: 70%)
- Memory utilization (target: 80%)

Scaling is configured between 1-10 tasks by default (adjustable in `terraform.tfvars`).

## Cost Optimization Tips

1. Use NAT Gateway Endpoints for VPC endpoints to reduce NAT Gateway costs
2. Consider using Fargate Spot for non-production environments
3. Adjust container CPU and memory based on actual usage
4. Set up CloudWatch alarms to monitor costs
5. Use scheduled scaling for predictable traffic patterns

## Troubleshooting

### Application not accessible
- Check ALB target group health
- Verify security group rules
- Check ECS service events
- Review CloudWatch logs

### Deployment fails
- Verify AWS credentials in GitHub Secrets
- Check ECR repository exists and permissions are correct
- Ensure ECS cluster and service names match
- Review GitHub Actions logs for detailed errors

### High costs
- Review NAT Gateway usage
- Check for orphaned resources
- Monitor ECS task count
- Review CloudWatch costs

## Cleanup

To destroy all infrastructure:

```bash
cd terraform
terraform destroy
```

**Note**: This will delete all resources including:
- VPC and networking components
- ECS cluster and services
- ECR repository and images
- Load balancer
- CloudWatch log groups

## Security Best Practices

1. **Never commit AWS credentials** - Use GitHub Secrets
2. **Use IAM roles with least privilege** - Task roles should have minimal permissions
3. **Enable VPC Flow Logs** - For network traffic monitoring
4. **Use secrets management** - AWS Secrets Manager or Parameter Store for sensitive data
5. **Enable container image scanning** - Already configured in ECR
6. **Use HTTPS** - Add SSL certificate to ALB for production
7. **Regular updates** - Keep base images and dependencies updated

## Next Steps

- Add HTTPS/SSL certificate to ALB
- Implement blue/green deployments
- Set up monitoring and alerting (CloudWatch Alarms)
- Add database connectivity
- Implement CI/CD for multiple environments (dev, staging, prod)
- Add integration tests to the CI/CD pipeline
- Set up backup and disaster recovery procedures

## License

ISC
