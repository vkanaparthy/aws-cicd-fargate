# AWS ECS Fargate Architecture Diagram

## Infrastructure Overview

This document illustrates the AWS architecture for the Node.js application deployed on ECS Fargate.

---

## Architecture Diagram

### Single-AZ Configuration (Development)

**Note**: This diagram shows the single-AZ configuration (`multi_az = false`) used for development. For production, set `multi_az = true` to use 2 NAT Gateways.

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                    INTERNET                                         │
│                                    (0.0.0.0/0)                                     │
└────────────────────────────────────────┬────────────────────────────────────────────┘
                                         │
                                         │ HTTPS/HTTP (Port 80/443)
                                         │
                    ┌────────────────────▼────────────────────┐
                    │     Internet Gateway (IGW)               │
                    │     nodejs-fargate-app-igw               │
                    └────────────────────┬─────────────────────┘
                                         │
                                         │
         ┌───────────────────────────────┼───────────────────────────────┐
         │                               │                               │
         │                               │                               │
    ┌────▼────────────────────┐   ┌────▼────────────────────┐          │
    │   Availability Zone 1     │   │   Availability Zone 2     │          │
    │   (us-east-1a)           │   │   (us-east-1b)           │          │
    │                          │   │                          │          │
    │ ┌──────────────────────┐ │   │ ┌──────────────────────┐ │          │
    │ │  PUBLIC SUBNET 1     │ │   │ │  PUBLIC SUBNET 2     │ │          │
    │ │  10.0.0.0/24         │ │   │ │  10.0.1.0/24         │ │          │
    │ │                      │ │   │ │                      │ │          │
    │ │  ┌────────────────┐ │ │   │ │                      │ │          │
    │ │  │  NAT Gateway   │ │ │   │ │  (No NAT Gateway)    │ │          │
    │ │  │  + Elastic IP  │ │ │   │ │  (Single-AZ Mode)    │ │          │
    │ │  └───────┬────────┘ │ │   │ │                      │ │          │
    │ │          │           │ │   │ │                      │ │          │
    │ │  ┌───────▼─────────┐ │ │   │ │  ┌─────────────────┐ │ │          │
    │ │  │ Application     │ │ │   │ │  │ Application     │ │ │          │
    │ │  │ Load Balancer   │ │ │   │ │  │ Load Balancer   │ │ │          │
    │ │  │ (ALB)           │ │ │   │ │  │ (ALB)           │ │ │          │
    │ │  │                 │ │ │   │ │  │                 │ │ │          │
    │ │  │ Target Group    │ │ │   │ │  │ Target Group    │ │ │          │
    │ │  │ Port: 3000      │ │ │   │ │  │ Port: 3000      │ │ │          │
    │ │  │ Health: /health │ │ │   │ │  │ Health: /health │ │ │          │
    │ │  └─────────────────┘ │ │   │ │  └─────────────────┘ │ │          │
    │ │                      │ │   │ │                      │ │          │
    │ │  Security Group:     │ │   │ │  Security Group:     │ │          │
    │ │  - Inbound: 80, 443  │ │   │ │  - Inbound: 80, 443  │ │          │
    │ │  - Outbound: All     │ │   │ │  - Outbound: All     │ │          │
    │ └──────────────────────┘ │   │ └──────────────────────┘ │          │
    │                          │   │                          │          │
    │ ┌──────────────────────┐ │   │ ┌──────────────────────┐ │          │
    │ │  PRIVATE SUBNET 1    │ │   │ │  PRIVATE SUBNET 2    │ │          │
    │ │  10.0.2.0/24         │ │   │ │  10.0.3.0/24         │ │          │
    │ │                      │ │   │ │                      │ │          │
    │ │  ┌────────────────┐ │ │   │ │  ┌────────────────┐ │ │          │
    │ │  │  ECS Fargate   │ │ │   │ │  │  ECS Fargate   │ │ │          │
    │ │  │  Tasks         │ │ │   │ │  │  Tasks         │ │ │          │
    │ │  │                │ │ │   │ │  │                │ │ │          │
    │ │  │  Container:    │ │ │   │ │  │  Container:    │ │ │          │
    │ │  │  Node.js App   │ │ │   │ │  │  Node.js App   │ │ │          │
    │ │  │  Port: 3000    │ │ │   │ │  │  Port: 3000    │ │ │          │
    │ │  │  CPU: 256      │ │ │   │ │  │  CPU: 256      │ │ │          │
    │ │  │  Memory: 512MB │ │ │   │ │  │  Memory: 512MB │ │ │          │
    │ │  └───────┬────────┘ │ │   │ │  └───────┬────────┘ │ │          │
    │ │          │          │ │   │ │          │          │ │          │
    │ │  ┌───────┴────────┐ │ │   │ │  ┌───────┴────────┐ │ │          │
    │ │  │ Security Group│ │ │   │ │  │ Security Group│ │ │          │
    │ │  │ - Inbound:3000│ │ │   │ │  │ - Inbound:3000│ │ │          │
    │ │  │   (from ALB)  │ │ │   │ │  │   (from ALB)  │ │ │          │
    │ │  │ - Outbound:All│ │ │   │ │  │ - Outbound:All│ │ │          │
    │ │  └───────┬───────┘ │ │   │ │  └───────┬───────┘ │ │          │
    │ │          │         │ │   │ │          │         │ │          │
    │ │  Route Table:      │ │   │ │  Route Table:      │ │          │
    │ │  0.0.0.0/0 ────────┼─┼───┼─┼─→ NAT GW 1        │ │          │
    │ │  (Both route       │ │   │ │  (Both route       │ │          │
    │ │   through same     │ │   │ │   through same     │ │          │
    │ │   NAT Gateway)     │ │   │ │   NAT Gateway)     │ │          │
    │ └────────────────────┘ │   │ └────────────────────┘ │          │
    └──────────────────────────┘   └──────────────────────────┘          │
                          │                  │                              │
                          └──────────────────┘                              │
                                  │                                         │
                    ┌─────────────▼─────────────┐                           │
                    │   Single NAT Gateway      │                           │
                    │   (Serves both subnets)   │                           │
                    │   Cost: ~$32/month        │                           │
                    └───────────────────────────┘                           │
                                                                          │
                    ┌────────────────────────────────────────────────────┘
                    │
                    │ VPC: nodejs-fargate-app-vpc
                    │ CIDR: 10.0.0.0/16
                    │ DNS: Enabled
                    │ Configuration: Single-AZ (multi_az = false)
                    │
┌───────────────────▼───────────────────────────────────────────────────────────────┐
│                         AWS SERVICES (Regional)                                    │
│                                                                                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐               │
│  │  ECS Cluster     │  │  ECR Repository  │  │  CloudWatch      │               │
│  │                  │  │                  │  │  Logs            │               │
│  │  - Fargate       │  │  - Container    │  │                  │               │
│  │  - Auto Scaling  │  │    Images       │  │  - App Logs      │               │
│  │  - Service       │  │  - Scanning     │  │  - Metrics       │               │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘               │
│                                                                                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐               │
│  │  IAM Roles       │  │  Route Tables    │  │  Security Groups │               │
│  │                  │  │                  │  │                  │               │
│  │  - Task Exec     │  │  - Public RT     │  │  - ALB SG        │               │
│  │  - Task Role     │  │  - Private RT 1   │  │  - ECS Tasks SG  │               │
│  │                  │  │  - Private RT 2   │  │                  │               │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘               │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Details

### Networking Components

#### VPC
- **Name**: `nodejs-fargate-app-vpc`
- **CIDR Block**: `10.0.0.0/16`
- **DNS Hostnames**: Enabled
- **DNS Support**: Enabled

#### Public Subnets (2)
- **Subnet 1**: `10.0.0.0/24` in Availability Zone 1
- **Subnet 2**: `10.0.1.0/24` in Availability Zone 2
- **Purpose**: Host NAT Gateways and Application Load Balancer
- **Auto-assign Public IP**: Enabled

#### Private Subnets (2)
- **Subnet 1**: `10.0.2.0/24` in Availability Zone 1
- **Subnet 2**: `10.0.3.0/24` in Availability Zone 2
- **Purpose**: Host ECS Fargate tasks (no direct internet access)
- **Auto-assign Public IP**: Disabled

#### Internet Gateway (IGW)
- **Name**: `nodejs-fargate-app-igw`
- **Purpose**: Provides internet access for public subnets
- **Attached to**: VPC

#### NAT Gateways (2)
- **NAT Gateway 1**: In Public Subnet 1 (AZ 1)
- **NAT Gateway 2**: In Public Subnet 2 (AZ 2)
- **Purpose**: Allows private subnets to access internet (outbound only)
- **Elastic IPs**: Each NAT Gateway has a dedicated Elastic IP

#### Route Tables
- **Public Route Table**: Routes `0.0.0.0/0` → Internet Gateway
- **Private Route Table 1**: Routes `0.0.0.0/0` → NAT Gateway 1
- **Private Route Table 2**: Routes `0.0.0.0/0` → NAT Gateway 2

---

### Application Components

#### Application Load Balancer (ALB)
- **Type**: Application Load Balancer
- **Scheme**: Internet-facing
- **Subnets**: Public Subnets (both AZs)
- **Listeners**: 
  - Port 80 (HTTP)
  - Port 443 (HTTPS) - can be configured
- **Target Group**: 
  - Port: 3000
  - Protocol: HTTP
  - Health Check: `/health` endpoint
  - Health Check Interval: 30 seconds

#### ECS Fargate Tasks
- **Launch Type**: Fargate
- **Subnets**: Private Subnets (both AZs)
- **Container Port**: 3000
- **CPU**: 256 (0.25 vCPU)
- **Memory**: 512 MB
- **Desired Count**: 1 (configurable)
- **Auto Scaling**: 
  - Min Capacity: 1
  - Max Capacity: 10
  - CPU Target: 70%
  - Memory Target: 80%

---

### Security Components

#### Security Groups

**ALB Security Group**
- **Inbound Rules**:
  - Port 80 from `0.0.0.0/0` (HTTP)
  - Port 443 from `0.0.0.0/0` (HTTPS)
- **Outbound Rules**:
  - All traffic allowed

**ECS Tasks Security Group**
- **Inbound Rules**:
  - Port 3000 from ALB Security Group only
- **Outbound Rules**:
  - All traffic allowed (for pulling images, logging, etc.)

---

### AWS Services

#### ECS Cluster
- **Name**: `nodejs-fargate-app-cluster`
- **Container Insights**: Enabled
- **Service**: `nodejs-fargate-app-service`

#### ECR Repository
- **Name**: `nodejs-fargate-app`
- **Image Scanning**: Enabled on push
- **Purpose**: Stores Docker container images

#### CloudWatch Logs
- **Log Group**: `/ecs/nodejs-fargate-app`
- **Retention**: 7 days
- **Purpose**: Centralized logging for ECS tasks

#### IAM Roles
- **Task Execution Role**: Allows ECS to pull images, write logs
- **Task Role**: Application-level permissions (if needed)

---

## Data Flow

### Inbound Traffic Flow
```
Internet → Internet Gateway → ALB (Public Subnets) → ECS Tasks (Private Subnets)
```

1. User requests arrive via Internet
2. Traffic enters through Internet Gateway
3. Application Load Balancer (in public subnets) receives traffic
4. ALB routes to healthy ECS tasks in private subnets
5. ECS tasks respond through ALB back to user

### Outbound Traffic Flow (from ECS Tasks)
```
ECS Tasks (Private Subnets) → NAT Gateway → Internet Gateway → Internet
```

1. ECS tasks need to pull images, send logs, or make API calls
2. Traffic routes through NAT Gateway in public subnet
3. NAT Gateway forwards through Internet Gateway
4. Response traffic follows reverse path

---

## Configuration Modes

### Single-AZ Mode (Development) - `multi_az = false`
- **NAT Gateways**: 1 NAT Gateway (~$32/month)
- **Cost Savings**: ~$32/month compared to multi-AZ
- **Use Case**: Development, testing, cost-sensitive environments
- **Route Tables**: Both private subnets route through single NAT Gateway

### Multi-AZ Mode (Production) - `multi_az = true`
- **NAT Gateways**: 2 NAT Gateways (~$64/month)
- **High Availability**: Redundant NAT Gateways for fault tolerance
- **Use Case**: Production, staging, high-availability requirements
- **Route Tables**: Each private subnet uses its own NAT Gateway

## High Availability

### Single-AZ Mode:
- **Load Balancing**: ALB distributes traffic across multiple tasks
- **Auto Scaling**: Automatically scales tasks based on CPU/Memory
- **Health Checks**: ALB monitors task health and routes only to healthy tasks
- **Note**: Single NAT Gateway (cost-optimized)

### Multi-AZ Mode:
- **Multi-AZ Deployment**: Resources deployed across 2 Availability Zones
- **Load Balancing**: ALB distributes traffic across multiple tasks
- **Auto Scaling**: Automatically scales tasks based on CPU/Memory
- **Health Checks**: ALB monitors task health and routes only to healthy tasks
- **Redundant NAT Gateways**: High availability for outbound traffic

---

## Security Features

- **Private Subnets**: ECS tasks have no direct internet access
- **Security Groups**: Restrictive firewall rules
- **NAT Gateway**: Outbound-only internet access for tasks
- **Encryption**: ECR images encrypted, CloudWatch logs encrypted
- **IAM Roles**: Least privilege access for tasks

---

## Cost Optimization

### Single-AZ Configuration (`multi_az = false`)
- **Single NAT Gateway**: Saves ~$32/month (~$384/year) compared to multi-AZ
- **Perfect for Development**: Reduces costs while maintaining functionality
- **Easy Migration**: Can switch to multi-AZ later with `terraform apply`

### General Cost Optimization Tips
- **Fargate Spot**: Can be enabled for cost savings (non-production)
- **Auto Scaling**: Scales down during low traffic
- **VPC Endpoints**: Consider VPC Endpoints for AWS services (ECR, CloudWatch) to reduce NAT Gateway data transfer costs
- **CloudWatch Logs**: 7-day retention to manage costs
- **Single-AZ Mode**: Use for development/staging environments

---

## Tags

All resources are tagged with:
- **vk-cicd**: `test`
- **Name**: Resource-specific name
- **Environment**: `production` (or as configured)

---

## Deployment Flow

```
GitHub Push → GitHub Actions → Build Docker Image → Push to ECR → 
Update ECS Task Definition → Deploy to ECS Fargate → ALB Routes Traffic
```

---

## Monitoring & Logging

- **CloudWatch Logs**: Application logs from ECS tasks
- **CloudWatch Metrics**: CPU, memory, request count
- **ALB Metrics**: Request count, response times, error rates
- **ECS Service Events**: Deployment and task status

---

## Scaling Behavior

- **CPU Utilization > 70%**: Scale out (add tasks)
- **Memory Utilization > 80%**: Scale out (add tasks)
- **Scale In**: When utilization drops below thresholds
- **Min Tasks**: 1 (always running)
- **Max Tasks**: 10 (prevents over-scaling)

---

## Network CIDR Summary

| Component | CIDR Block | Purpose |
|-----------|------------|---------|
| VPC | 10.0.0.0/16 | Main VPC |
| Public Subnet 1 | 10.0.0.0/24 | AZ 1 - NAT GW, ALB |
| Public Subnet 2 | 10.0.1.0/24 | AZ 2 - NAT GW, ALB |
| Private Subnet 1 | 10.0.2.0/24 | AZ 1 - ECS Tasks |
| Private Subnet 2 | 10.0.3.0/24 | AZ 2 - ECS Tasks |

---

## Ports & Protocols

| Component | Port | Protocol | Direction |
|-----------|------|----------|-----------|
| ALB Listener | 80 | HTTP | Inbound |
| ALB Listener | 443 | HTTPS | Inbound |
| Container | 3000 | HTTP | Internal |
| Health Check | 3000 | HTTP | Internal |

---

This architecture provides a secure, scalable, and highly available deployment for the Node.js application on AWS ECS Fargate.
