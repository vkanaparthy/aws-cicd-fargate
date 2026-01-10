#!/bin/bash

# Setup script for AWS ECS Fargate CI/CD Pipeline
# This script helps verify prerequisites and guides through setup

set -e

echo "=========================================="
echo "AWS ECS Fargate CI/CD Setup Helper"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check command exists
check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 is installed"
        return 0
    else
        echo -e "${RED}✗${NC} $1 is NOT installed"
        return 1
    fi
}

# Function to check version
check_version() {
    local cmd=$1
    local min_version=$2
    local current_version=$3
    
    if [ "$(printf '%s\n' "$min_version" "$current_version" | sort -V | head -n1)" = "$min_version" ]; then
        echo -e "${GREEN}✓${NC} $cmd version $current_version meets requirement (>= $min_version)"
        return 0
    else
        echo -e "${RED}✗${NC} $cmd version $current_version does NOT meet requirement (>= $min_version)"
        return 1
    fi
}

echo "Step 1: Checking Prerequisites..."
echo "-----------------------------------"

# Check Node.js
if check_command "node"; then
    NODE_VERSION=$(node --version | sed 's/v//')
    check_version "node" "18.0.0" "$NODE_VERSION" || echo -e "${YELLOW}Warning: Node.js version should be >= 18.0.0${NC}"
else
    echo -e "${RED}Please install Node.js from https://nodejs.org/${NC}"
    exit 1
fi

# Check npm
if check_command "npm"; then
    NPM_VERSION=$(npm --version)
    echo -e "${GREEN}✓${NC} npm version $NPM_VERSION"
else
    echo -e "${RED}npm is not installed${NC}"
    exit 1
fi

# Check Docker
if check_command "docker"; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    echo -e "${GREEN}✓${NC} Docker version $DOCKER_VERSION"
else
    echo -e "${RED}Please install Docker from https://www.docker.com/products/docker-desktop${NC}"
    exit 1
fi

# Check AWS CLI
if check_command "aws"; then
    AWS_VERSION=$(aws --version | awk '{print $1}' | cut -d'/' -f2)
    echo -e "${GREEN}✓${NC} AWS CLI version $AWS_VERSION"
else
    echo -e "${RED}Please install AWS CLI from https://aws.amazon.com/cli/${NC}"
    exit 1
fi

# Check Terraform
if check_command "terraform"; then
    TF_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
    check_version "terraform" "1.0.0" "$TF_VERSION" || echo -e "${YELLOW}Warning: Terraform version should be >= 1.0.0${NC}"
else
    echo -e "${RED}Please install Terraform from https://www.terraform.io/downloads${NC}"
    exit 1
fi

echo ""
echo "Step 2: Checking AWS Configuration..."
echo "--------------------------------------"

# Check AWS credentials
if aws sts get-caller-identity &> /dev/null; then
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
    echo -e "${GREEN}✓${NC} AWS credentials are configured"
    echo -e "  Account: $AWS_ACCOUNT"
    echo -e "  User/Role: $AWS_USER"
else
    echo -e "${RED}✗${NC} AWS credentials are NOT configured"
    echo -e "${YELLOW}Run: aws configure${NC}"
    exit 1
fi

# Get AWS region
AWS_REGION=$(aws configure get region || echo "us-east-1")
echo -e "${GREEN}✓${NC} AWS Region: $AWS_REGION"

echo ""
echo "Step 3: Checking Project Files..."
echo "----------------------------------"

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo -e "${RED}✗${NC} package.json not found. Are you in the project root?"
    exit 1
fi
echo -e "${GREEN}✓${NC} Project files found"

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}⚠${NC} node_modules not found. Installing dependencies..."
    npm install
else
    echo -e "${GREEN}✓${NC} Dependencies installed"
fi

# Check terraform directory
if [ ! -d "terraform" ]; then
    echo -e "${RED}✗${NC} terraform directory not found"
    exit 1
fi
echo -e "${GREEN}✓${NC} Terraform directory found"

# Check if terraform.tfvars exists
if [ ! -f "terraform/terraform.tfvars" ]; then
    echo -e "${YELLOW}⚠${NC} terraform.tfvars not found"
    if [ -f "terraform/terraform.tfvars.example" ]; then
        echo -e "${YELLOW}  Copying terraform.tfvars.example to terraform.tfvars${NC}"
        cp terraform/terraform.tfvars.example terraform/terraform.tfvars
        echo -e "${GREEN}✓${NC} Created terraform.tfvars from example"
        echo -e "${YELLOW}  Please edit terraform/terraform.tfvars with your values${NC}"
    fi
else
    echo -e "${GREEN}✓${NC} terraform.tfvars found"
fi

echo ""
echo "Step 4: Testing Application Locally..."
echo "--------------------------------------"

# Test if app starts (quick test)
timeout 5 npm start > /dev/null 2>&1 &
APP_PID=$!
sleep 2

if kill -0 $APP_PID 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Application starts successfully"
    kill $APP_PID 2>/dev/null || true
else
    echo -e "${YELLOW}⚠${NC} Could not verify application start (this is okay)"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Prerequisites Check Complete!${NC}"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Review and edit terraform/terraform.tfvars if needed"
echo "2. Run: cd terraform && terraform init"
echo "3. Run: terraform plan"
echo "4. Run: terraform apply"
echo ""
echo "For detailed instructions, see QUICKSTART.md"
echo ""
