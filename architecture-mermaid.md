# AWS ECS Fargate Architecture - Mermaid Diagram

This diagram can be rendered in GitHub, GitLab, or any Mermaid-compatible viewer.

# Single-AZ Configuration (Development)

**Configuration**: `multi_az = false` (Single NAT Gateway)

```mermaid
graph TB
    subgraph Internet["🌐 Internet"]
        Users["👥 Users"]
    end
    
    subgraph AWS["☁️ AWS Cloud - us-east-1<br/>💰 Single-AZ Mode: ~$32/month NAT Gateway"]
        subgraph VPC["VPC: nodejs-fargate-app-vpc<br/>CIDR: 10.0.0.0/16<br/>Config: multi_az = false"]
            IGW["🌐 Internet Gateway<br/>nodejs-fargate-app-igw"]
            
            subgraph AZ1["Availability Zone 1 (us-east-1a)"]
                subgraph PublicSubnet1["Public Subnet 1<br/>10.0.0.0/24"]
                    NAT1["🔀 NAT Gateway<br/>+ Elastic IP<br/>💰 Single NAT GW"]
                    ALB["⚖️ Application Load Balancer<br/>Port: 80, 443"]
                end
                
                subgraph PrivateSubnet1["Private Subnet 1<br/>10.0.2.0/24"]
                    ECS1["📦 ECS Fargate Task 1<br/>Node.js App<br/>Port: 3000<br/>CPU: 256 | Memory: 512MB"]
                end
            end
            
            subgraph AZ2["Availability Zone 2 (us-east-1b)"]
                subgraph PublicSubnet2["Public Subnet 2<br/>10.0.1.0/24<br/>⚠️ No NAT Gateway<br/>(ALB requirement only)"]
                end
                
                subgraph PrivateSubnet2["Private Subnet 2<br/>10.0.3.0/24"]
                    ECS2["📦 ECS Fargate Task 2<br/>Node.js App<br/>Port: 3000<br/>CPU: 256 | Memory: 512MB"]
                end
            end
            
            subgraph SecurityGroups["🔒 Security Groups"]
                ALBSG["ALB Security Group<br/>Inbound: 80, 443<br/>Outbound: All"]
                ECSSG["ECS Tasks Security Group<br/>Inbound: 3000 from ALB<br/>Outbound: All"]
            end
            
            subgraph RouteTables["🗺️ Route Tables"]
                PublicRT["Public Route Table<br/>0.0.0.0/0 → IGW"]
                PrivateRT1["Private Route Table 1<br/>0.0.0.0/0 → NAT GW<br/>(Single NAT)"]
                PrivateRT2["Private Route Table 2<br/>0.0.0.0/0 → NAT GW<br/>(Single NAT)"]
            end
        end
        
        subgraph Services["AWS Services"]
            ECR["📦 ECR Repository<br/>nodejs-fargate-app<br/>Image Scanning"]
            ECSCluster["🎯 ECS Cluster<br/>nodejs-fargate-app-cluster<br/>Auto Scaling Enabled"]
            CloudWatch["📊 CloudWatch Logs<br/>/ecs/nodejs-fargate-app<br/>Retention: 7 days"]
            IAMRole1["👤 IAM Role<br/>Task Execution Role"]
            IAMRole2["👤 IAM Role<br/>Task Role"]
        end
    end
    
    %% Internet connections
    Users -->|HTTPS/HTTP| IGW
    IGW --> ALB
    
    %% VPC connections
    ALB -->|Port 3000| ECS1
    ALB -->|Port 3000| ECS2
    
    %% NAT Gateway connections - Single NAT Gateway serves both subnets
    NAT1 -.->|Outbound| IGW
    ECS1 -.->|Outbound| NAT1
    ECS2 -.->|Outbound| NAT1
    
    %% Security Groups
    ALB --> ALBSG
    ALBSG --> ECSSG
    ECSSG --> ECS1
    ECSSG --> ECS2
    
    %% Route Tables - Both route through single NAT Gateway
    PublicSubnet1 --> PublicRT
    PublicSubnet2 --> PublicRT
    PrivateSubnet1 --> PrivateRT1
    PrivateSubnet2 --> PrivateRT2
    PrivateRT1 -.->|Routes via| NAT1
    PrivateRT2 -.->|Routes via| NAT1
    
    %% AWS Services connections
    ECR -->|Pull Images| ECS1
    ECR -->|Pull Images| ECS2
    ECSCluster --> ECS1
    ECSCluster --> ECS2
    ECS1 -->|Logs| CloudWatch
    ECS2 -->|Logs| CloudWatch
    IAMRole1 --> ECS1
    IAMRole1 --> ECS2
    IAMRole2 --> ECS1
    IAMRole2 --> ECS2
    
    %% Styling
    classDef vpcStyle fill:#ff9999,stroke:#333,stroke-width:3px
    classDef publicStyle fill:#99ccff,stroke:#333,stroke-width:2px
    classDef privateStyle fill:#ffcc99,stroke:#333,stroke-width:2px
    classDef serviceStyle fill:#99ff99,stroke:#333,stroke-width:2px
    classDef natStyle fill:#ffcc00,stroke:#333,stroke-width:3px
    
    class VPC vpcStyle
    class PublicSubnet1,PublicSubnet2 publicStyle
    class PrivateSubnet1,PrivateSubnet2 privateStyle
    class ECR,ECSCluster,CloudWatch,IAMRole1,IAMRole2 serviceStyle
    class NAT1 natStyle
```

---

# Multi-AZ Configuration (Production)

**Configuration**: `multi_az = true` (Two NAT Gateways)

```mermaid
graph TB
    subgraph Internet["🌐 Internet"]
        Users["👥 Users"]
    end
    
    subgraph AWS["☁️ AWS Cloud - us-east-1<br/>🏗️ Multi-AZ Mode: ~$64/month NAT Gateways"]
        subgraph VPC["VPC: nodejs-fargate-app-vpc<br/>CIDR: 10.0.0.0/16<br/>Config: multi_az = true"]
            IGW["🌐 Internet Gateway<br/>nodejs-fargate-app-igw"]
            
            subgraph AZ1["Availability Zone 1 (us-east-1a)"]
                subgraph PublicSubnet1["Public Subnet 1<br/>10.0.0.0/24"]
                    NAT1["🔀 NAT Gateway 1<br/>+ Elastic IP"]
                    ALB["⚖️ Application Load Balancer<br/>Port: 80, 443"]
                end
                
                subgraph PrivateSubnet1["Private Subnet 1<br/>10.0.2.0/24"]
                    ECS1["📦 ECS Fargate Task 1<br/>Node.js App<br/>Port: 3000<br/>CPU: 256 | Memory: 512MB"]
                end
            end
            
            subgraph AZ2["Availability Zone 2 (us-east-1b)"]
                subgraph PublicSubnet2["Public Subnet 2<br/>10.0.1.0/24"]
                    NAT2["🔀 NAT Gateway 2<br/>+ Elastic IP"]
                end
                
                subgraph PrivateSubnet2["Private Subnet 2<br/>10.0.3.0/24"]
                    ECS2["📦 ECS Fargate Task 2<br/>Node.js App<br/>Port: 3000<br/>CPU: 256 | Memory: 512MB"]
                end
            end
            
            subgraph SecurityGroups["🔒 Security Groups"]
                ALBSG["ALB Security Group<br/>Inbound: 80, 443<br/>Outbound: All"]
                ECSSG["ECS Tasks Security Group<br/>Inbound: 3000 from ALB<br/>Outbound: All"]
            end
            
            subgraph RouteTables["🗺️ Route Tables"]
                PublicRT["Public Route Table<br/>0.0.0.0/0 → IGW"]
                PrivateRT1["Private Route Table 1<br/>0.0.0.0/0 → NAT GW 1"]
                PrivateRT2["Private Route Table 2<br/>0.0.0.0/0 → NAT GW 2"]
            end
        end
        
        subgraph Services["AWS Services"]
            ECR["📦 ECR Repository<br/>nodejs-fargate-app<br/>Image Scanning"]
            ECSCluster["🎯 ECS Cluster<br/>nodejs-fargate-app-cluster<br/>Auto Scaling Enabled"]
            CloudWatch["📊 CloudWatch Logs<br/>/ecs/nodejs-fargate-app<br/>Retention: 7 days"]
            IAMRole1["👤 IAM Role<br/>Task Execution Role"]
            IAMRole2["👤 IAM Role<br/>Task Role"]
        end
    end
    
    %% Internet connections
    Users -->|HTTPS/HTTP| IGW
    IGW --> ALB
    
    %% VPC connections
    ALB -->|Port 3000| ECS1
    ALB -->|Port 3000| ECS2
    
    %% NAT Gateway connections
    NAT1 -.->|Outbound| IGW
    NAT2 -.->|Outbound| IGW
    ECS1 -.->|Outbound| NAT1
    ECS2 -.->|Outbound| NAT2
    
    %% Security Groups
    ALB --> ALBSG
    ALBSG --> ECSSG
    ECSSG --> ECS1
    ECSSG --> ECS2
    
    %% Route Tables
    PublicSubnet1 --> PublicRT
    PublicSubnet2 --> PublicRT
    PrivateSubnet1 --> PrivateRT1
    PrivateSubnet2 --> PrivateRT2
    
    %% AWS Services connections
    ECR -->|Pull Images| ECS1
    ECR -->|Pull Images| ECS2
    ECSCluster --> ECS1
    ECSCluster --> ECS2
    ECS1 -->|Logs| CloudWatch
    ECS2 -->|Logs| CloudWatch
    IAMRole1 --> ECS1
    IAMRole1 --> ECS2
    IAMRole2 --> ECS1
    IAMRole2 --> ECS2
    
    %% Styling
    classDef vpcStyle fill:#ff9999,stroke:#333,stroke-width:3px
    classDef publicStyle fill:#99ccff,stroke:#333,stroke-width:2px
    classDef privateStyle fill:#ffcc99,stroke:#333,stroke-width:2px
    classDef serviceStyle fill:#99ff99,stroke:#333,stroke-width:2px
    
    class VPC vpcStyle
    class PublicSubnet1,PublicSubnet2 publicStyle
    class PrivateSubnet1,PrivateSubnet2 privateStyle
    class ECR,ECSCluster,CloudWatch,IAMRole1,IAMRole2 serviceStyle
```

## Architecture Components

### 🌐 Internet Layer
- **Users**: External users accessing the application

### ☁️ VPC Layer
- **VPC**: Main virtual network (10.0.0.0/16)
- **Internet Gateway**: Provides internet access
- **Public Subnets**: Host NAT Gateways and ALB
- **Private Subnets**: Host ECS Fargate tasks

### ⚖️ Load Balancing Layer
- **Application Load Balancer**: Distributes traffic across tasks
- **Target Group**: Routes to healthy tasks on port 3000

### 📦 Compute Layer
- **ECS Fargate Tasks**: Containerized Node.js applications
- **Auto Scaling**: Scales based on CPU/Memory utilization

### 🔒 Security Layer
- **Security Groups**: Firewall rules for ALB and ECS tasks
- **IAM Roles**: Permissions for task execution and application access

### 📊 Observability Layer
- **CloudWatch Logs**: Centralized logging
- **CloudWatch Metrics**: Performance monitoring

### 🗄️ Storage Layer
- **ECR**: Container image repository

## Traffic Flow

### Inbound (User → Application)
```
Users → Internet Gateway → ALB → ECS Tasks (Private Subnets)
```

### Outbound (Application → Internet)
```
ECS Tasks → NAT Gateway → Internet Gateway → Internet
```

## Configuration Modes

### Single-AZ Mode (Development) - `multi_az = false`
- ✅ **1 NAT Gateway** (~$32/month)
- ✅ Cost-optimized for development
- ✅ Both private subnets route through single NAT Gateway
- ⚠️ Less redundancy (single NAT Gateway)

### Multi-AZ Mode (Production) - `multi_az = true`
- ✅ **2 NAT Gateways** (~$64/month)
- ✅ High availability and redundancy
- ✅ Each private subnet uses its own NAT Gateway
- ✅ Production-grade setup

## High Availability Features

### Single-AZ Mode:
- ✅ Load balancing across multiple tasks
- ✅ Auto-scaling based on demand
- ✅ Health checks and automatic failover
- ⚠️ Single NAT Gateway (cost savings)

### Multi-AZ Mode:
- ✅ Multi-AZ deployment (2 Availability Zones)
- ✅ Load balancing across multiple tasks
- ✅ Auto-scaling based on demand
- ✅ Health checks and automatic failover
- ✅ Redundant NAT Gateways
