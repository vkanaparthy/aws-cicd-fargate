# Development Configuration Guide

## Single-AZ vs Multi-AZ Configuration

This guide explains how to configure your infrastructure for development (single-AZ) vs production (multi-AZ).

---

## Configuration Options

### Development (Single-AZ) - Cost Optimized 💰

**Use when**: Development, testing, or cost-sensitive environments

**Configuration**:
```hcl
multi_az = false
```

**What this does**:
- ✅ Uses **1 NAT Gateway** instead of 2
- ✅ Saves **~$32/month** (~$384/year)
- ✅ Still uses 2 subnets (required by ALB)
- ✅ Both private subnets route through single NAT Gateway
- ⚠️ Less redundancy (single point of failure for NAT)

**Cost Savings**:
- NAT Gateway: 1 × $32/month = **$32/month**
- Total savings: **~$32/month**

**Example**: `terraform.tfvars.dev.example`

---

### Production (Multi-AZ) - High Availability 🏗️

**Use when**: Production, staging, or high-availability requirements

**Configuration**:
```hcl
multi_az = true
```

**What this does**:
- ✅ Uses **2 NAT Gateways** (one per AZ)
- ✅ High availability (if one NAT fails, other handles traffic)
- ✅ Better performance (traffic stays in same AZ)
- ✅ Production-grade redundancy

**Cost**:
- NAT Gateway: 2 × $32/month = **$64/month**

**Example**: `terraform.tfvars.prod.example`

---

## How to Use

### For Development:

1. **Copy the dev example**:
   ```bash
   cp terraform.tfvars.dev.example terraform.tfvars
   ```

2. **Or edit your existing terraform.tfvars**:
   ```hcl
   multi_az = false
   environment = "dev"
   ```

3. **Deploy**:
   ```bash
   terraform plan
   terraform apply
   ```

### For Production:

1. **Copy the prod example**:
   ```bash
   cp terraform.tfvars.prod.example terraform.tfvars
   ```

2. **Or edit your existing terraform.tfvars**:
   ```hcl
   multi_az = true
   environment = "production"
   ```

3. **Deploy**:
   ```bash
   terraform plan
   terraform apply
   ```

---

## Architecture Comparison

### Single-AZ (Development)

```
                    ┌─────────────────┐
                    │  Internet GW    │
                    └────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼────┐          ┌────▼────┐         ┌────▼────┐
   │ Public  │          │ Public  │         │ Private │
   │Subnet 1 │          │Subnet 2 │         │Subnet 1 │
   │  AZ 1   │          │  AZ 2   │         │  AZ 1   │
   │         │          │         │         │         │
   │ ┌─────┐ │          │         │         │ ┌─────┐ │
   │ │ NAT │ │          │         │         │ │ECS  │ │
   │ │ GW  │ │          │         │         │ │Task │ │
   │ └──┬──┘ │          │         │         │ └──┬──┘ │
   └────┼────┘          └─────────┘         └────┼────┘
        │                                         │
        │              ┌─────────────────┐       │
        └──────────────►│  Single NAT GW  │◄─────┘
                        │  (Both subnets) │
                        └─────────────────┘
```

**Key Points**:
- 1 NAT Gateway serves both private subnets
- ALB still requires 2 subnets (in different AZs)
- Cost-effective for development

### Multi-AZ (Production)

```
                    ┌─────────────────┐
                    │  Internet GW    │
                    └────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼────┐          ┌────▼────┐         ┌────▼────┐
   │ Public  │          │ Public  │         │ Private │
   │Subnet 1 │          │Subnet 2 │         │Subnet 1 │
   │  AZ 1   │          │  AZ 2   │         │  AZ 1   │
   │         │          │         │         │         │
   │ ┌─────┐ │          │ ┌─────┐ │         │ ┌─────┐ │
   │ │ NAT │ │          │ │ NAT │ │         │ │ECS  │ │
   │ │ GW  │ │          │ │ GW  │ │         │ │Task │ │
   │ └──┬──┘ │          │ └──┬──┘ │         │ └──┬──┘ │
   └────┼────┘          └────┼────┘         └────┼────┘
        │                    │                    │
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
                    ┌────────▼────────┐
                    │  Private        │
                    │  Subnet 2       │
                    │  AZ 2           │
                    │  ┌─────┐        │
                    │  │ECS  │        │
                    │  │Task │        │
                    │  └─────┘        │
                    └─────────────────┘
```

**Key Points**:
- 2 NAT Gateways (one per AZ)
- Each private subnet uses its own NAT Gateway
- High availability and redundancy

---

## Cost Comparison

| Component | Single-AZ (Dev) | Multi-AZ (Prod) | Savings |
|-----------|----------------|-----------------|---------|
| NAT Gateway | 1 × $32 = $32/month | 2 × $32 = $64/month | **$32/month** |
| Elastic IP | 1 × $0 = $0 | 2 × $0 = $0 | $0 |
| Data Transfer | Same | Same | $0 |
| **Total** | **$32/month** | **$64/month** | **$32/month** |

**Annual Savings**: ~$384/year

---

## Important Notes

### ALB Requirement
⚠️ **Application Load Balancer requires at least 2 subnets in different Availability Zones**

This means:
- Even in single-AZ mode, we still create 2 subnets
- But both private subnets route through the single NAT Gateway
- This satisfies ALB requirements while saving costs

### Migration Between Configurations

**Switching from Single-AZ to Multi-AZ**:
```bash
# Update terraform.tfvars
multi_az = true

# Apply changes
terraform plan  # Review changes
terraform apply # Adds second NAT Gateway
```

**Switching from Multi-AZ to Single-AZ**:
```bash
# Update terraform.tfvars
multi_az = false

# Apply changes
terraform plan  # Review changes (will destroy one NAT Gateway)
terraform apply # Removes second NAT Gateway
```

---

## Recommendations

### Development Environment
✅ Use `multi_az = false`
- Saves ~$32/month
- Sufficient for development/testing
- Can upgrade to multi-AZ later

### Staging Environment
✅ Use `multi_az = true` (if budget allows)
- Test production-like setup
- Catch multi-AZ issues early

### Production Environment
✅ Always use `multi_az = true`
- High availability required
- Redundancy for critical workloads
- Production-grade setup

---

## Quick Reference

```bash
# Development setup
cp terraform.tfvars.dev.example terraform.tfvars
terraform apply

# Production setup
cp terraform.tfvars.prod.example terraform.tfvars
terraform apply
```

---

## Troubleshooting

### Issue: ALB creation fails
**Solution**: ALB requires 2 subnets in different AZs. Ensure `multi_az` doesn't affect subnet count.

### Issue: NAT Gateway costs too high
**Solution**: Use `multi_az = false` for development. Consider VPC Endpoints for AWS services.

### Issue: Need to switch configurations
**Solution**: Update `multi_az` in `terraform.tfvars` and run `terraform apply`.
