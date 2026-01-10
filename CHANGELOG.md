# Changelog - CodeDeploy Blue/Green Deployment & NAT Gateway Removal

## Summary of Changes

This update implements blue/green deployments using AWS CodeDeploy and removes NAT Gateways to reduce costs.

---

## Major Changes

### ✅ Added: CodeDeploy Blue/Green Deployments

**Components Added:**
- CodeDeploy Application (`nodejs-fargate-app-codedeploy-app`)
- CodeDeploy Deployment Group with blue/green configuration
- IAM Role for CodeDeploy
- Two Target Groups (Blue and Green)
- AppSpec file (`appspec.yml`)

**Benefits:**
- Zero-downtime deployments
- Automatic rollback on failure
- Canary testing capability
- Production-grade deployment strategy

### ✅ Removed: NAT Gateways

**Components Removed:**
- NAT Gateways (1 or 2 depending on `multi_az` setting)
- Elastic IPs for NAT Gateways
- Route table routes to NAT Gateways from private subnets

**Cost Savings:**
- ~$32-64/month (depending on multi-AZ setting)
- ~$384-768/year

### ✅ Added: VPC Endpoints

**Components Added:**
- VPC Endpoint for ECR Docker API (Interface)
- VPC Endpoint for ECR API (Interface)
- VPC Endpoint for CloudWatch Logs (Interface)
- VPC Endpoint for S3 (Gateway - no cost)
- Security Group for VPC Endpoints

**Cost:**
- ~$21/month for Interface Endpoints
- **Net Savings**: ~$11-43/month vs NAT Gateway

**Benefits:**
- More secure (traffic stays within AWS network)
- Better performance (private AWS network)
- No data transfer costs for AWS services

---

## File Changes

### Terraform Files

#### `terraform/main.tf`
- ✅ Removed NAT Gateway resources
- ✅ Removed Elastic IP resources for NAT
- ✅ Updated private route tables (no NAT routes)
- ✅ Added VPC Endpoints (ECR, CloudWatch, S3)
- ✅ Added VPC Endpoint security group
- ✅ Split target group into Blue and Green
- ✅ Updated ECS service for CodeDeploy deployment controller
- ✅ Added CodeDeploy application
- ✅ Added CodeDeploy deployment group
- ✅ Added CodeDeploy IAM role

#### `terraform/outputs.tf`
- ✅ Added `target_group_blue_arn`
- ✅ Added `target_group_green_arn`
- ✅ Added `codedeploy_app_name`
- ✅ Added `codedeploy_deployment_group_name`

### GitHub Actions

#### `.github/workflows/deploy.yml`
- ✅ Updated to use CodeDeploy instead of direct ECS deployment
- ✅ Added task definition registration step
- ✅ Added AppSpec file generation
- ✅ Added CodeDeploy deployment creation
- ✅ Added deployment wait step

### New Files

#### `appspec.yml`
- ✅ Created AppSpec file template for CodeDeploy
- ✅ Defines ECS service deployment configuration

#### `scripts/generate-appspec.sh`
- ✅ Helper script to generate AppSpec file
- ✅ Extracts ECS service configuration automatically

#### `CODEDEPLOY_SETUP.md`
- ✅ Complete documentation for CodeDeploy setup
- ✅ Deployment process explanation
- ✅ Troubleshooting guide

---

## Migration Steps

### Before Deploying

1. **Review Changes**:
   ```bash
   cd terraform
   terraform plan
   ```

2. **Important Notes**:
   - NAT Gateways will be destroyed
   - VPC Endpoints will be created
   - CodeDeploy resources will be created
   - ECS service will be updated (may cause brief interruption on first apply)

3. **Backup Current State** (if needed):
   ```bash
   terraform state pull > terraform-state-backup.json
   ```

### Deploying Changes

```bash
cd terraform

# Review plan
terraform plan

# Apply changes
terraform apply
```

### After Deployment

1. **Verify VPC Endpoints**:
   ```bash
   aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"
   ```

2. **Verify CodeDeploy**:
   ```bash
   terraform output codedeploy_app_name
   terraform output codedeploy_deployment_group_name
   ```

3. **Test Deployment**:
   - Push a change to trigger GitHub Actions
   - Monitor CodeDeploy deployment in AWS Console

---

## Breaking Changes

### ⚠️ ECS Service Update

The ECS service deployment controller is changed from `ECS` to `CODE_DEPLOY`. This means:
- Direct ECS service updates via `aws ecs update-service` will no longer work
- All deployments must go through CodeDeploy
- First deployment after migration will use CodeDeploy

### ⚠️ No Internet Access from Private Subnets

Private subnets no longer have internet access:
- ✅ ECR image pulls work via VPC Endpoint
- ✅ CloudWatch logs work via VPC Endpoint
- ✅ S3 access works via VPC Endpoint
- ❌ External API calls won't work (unless using VPC Endpoints)

**Solution**: If you need external API access, add VPC Endpoints for those services or use AWS API Gateway.

---

## Configuration Updates Needed

### GitHub Actions Secrets

No new secrets needed - existing AWS credentials are sufficient.

### IAM Permissions

Your GitHub Actions IAM user needs these additional permissions:
- `codedeploy:CreateDeployment`
- `codedeploy:GetDeployment`
- `codedeploy:GetDeploymentConfig`
- `codedeploy:GetApplication`
- `ecs:RegisterTaskDefinition`
- `ecs:DescribeServices`

---

## Rollback Plan

If you need to rollback:

1. **Restore NAT Gateways**:
   ```bash
   # Revert terraform/main.tf changes
   git checkout HEAD~1 terraform/main.tf
   terraform apply
   ```

2. **Revert ECS Service**:
   ```bash
   # Change deployment_controller back to ECS
   # Update terraform/main.tf
   terraform apply
   ```

---

## Testing Checklist

- [ ] VPC Endpoints created successfully
- [ ] ECS tasks can pull images from ECR
- [ ] ECS tasks can send logs to CloudWatch
- [ ] CodeDeploy application created
- [ ] CodeDeploy deployment group created
- [ ] Blue target group receives traffic
- [ ] GitHub Actions workflow completes successfully
- [ ] CodeDeploy deployment succeeds
- [ ] Green target group receives traffic after switch
- [ ] Blue tasks terminated after successful deployment

---

## Cost Impact

| Item | Before | After | Change |
|------|--------|-------|--------|
| NAT Gateway | $32-64/month | $0 | **-$32-64/month** |
| VPC Endpoints | $0 | ~$21/month | +$21/month |
| CodeDeploy | $0 | $0 | $0 |
| **Total** | **$32-64/month** | **~$21/month** | **-$11-43/month** |

**Annual Savings**: ~$132-516/year

---

## Next Steps

1. ✅ Review and test the changes
2. ✅ Update IAM permissions for GitHub Actions
3. ✅ Deploy infrastructure changes
4. ✅ Test blue/green deployment
5. ✅ Monitor costs and performance

---

## Support

For issues or questions:
- See `CODEDEPLOY_SETUP.md` for detailed documentation
- Check CloudWatch Logs for deployment issues
- Review CodeDeploy deployment history in AWS Console
