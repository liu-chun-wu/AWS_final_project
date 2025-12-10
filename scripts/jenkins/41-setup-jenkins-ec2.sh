#!/bin/bash

################################################################################
# Jenkins EC2 Setup Script - Deploy CI/CD Server on AWS
################################################################################
#
# Script: 41-setup-jenkins-ec2.sh
# Purpose: Launch and configure Jenkins on AWS EC2 for CI/CD automation
# Usage: ./41-setup-jenkins-ec2.sh [--demo|--prod]
#
# What is AWS EC2 (Elastic Compute Cloud)?
# - Virtual servers in the cloud (like your own computer in AWS)
# - Choose instance type (CPU, memory, storage specifications)
# - Pay only for what you use (per-hour pricing)
# - Can start, stop, terminate instances as needed
# - Full control over operating system and installed software
#
# What is Jenkins?
# - Open-source CI/CD automation server
# - Runs build/test/deploy pipelines automatically
# - Triggered by Git commits (via webhooks)
# - Extensible with 1000+ plugins
# - Industry standard for DevOps automation
#
# This script performs:
# 1. Prerequisites validation (AWS CLI, credentials, key pairs)
# 2. Security Group creation (firewall rules for ports 22, 8080, 443)
# 3. EC2 instance launch (t3.medium with Amazon Linux 2023 by default)
# 4. User Data script execution (installs Jenkins, Docker, AWS tools)
# 5. Jenkins initialization and password retrieval
# 6. Instance information saved for other scripts
#
# What you'll learn:
# - EC2 instance types and pricing
# - Security Groups (AWS firewall)
# - IAM Instance Profiles (EC2 permissions)
# - User Data scripts (automated initialization)
# - AMI selection (Amazon Machine Images)
# - EC2 lifecycle management
#
# AWS Services Used:
# - EC2 - Virtual server for Jenkins
# - VPC - Network for the instance
# - Security Groups - Firewall rules
# - IAM - Instance profile for AWS API access
# - Systems Manager - Optional: Parameter Store for secrets
#
# Prerequisites:
# - AWS CLI configured with valid credentials
# - EC2 key pair exists in the region
# - Sufficient EC2 instance limits
# - Internet connectivity for package downloads
#
# Cost:
# - EC2 t3.medium: ~$0.0416/hour = ~$30/month (24/7 running)
# - EBS 20GB gp3: ~$2/month
# - Data transfer: Minimal for CI/CD workloads
# - Total: ~$19/month or ~$5-8/month if stopped when not in use
#
################################################################################

set -e  # Exit immediately if any command fails

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "${SCRIPT_DIR}/env-common.sh"

################################################################################
# Helper Functions for Output Formatting
################################################################################

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "  $1"
}

print_command() {
    echo -e "${CYAN}  \$ $1${NC}"
}

print_explain() {
    echo -e "${YELLOW}  ℹ $1${NC}"
}

################################################################################
# Parse Arguments
################################################################################

ENVIRONMENT=""
if [ "$1" == "--demo" ]; then
    ENVIRONMENT="demo"
elif [ "$1" == "--prod" ]; then
    ENVIRONMENT="prod"
else
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  ERROR: Environment required                                   ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Usage: $0 [--demo|--prod]"
    echo ""
    echo "Options:"
    echo "  --demo  Setup Jenkins for demo environment"
    echo "  --prod  Setup Jenkins for production environment"
    echo ""
    echo "What this does:"
    echo "  • Launches EC2 instance with Jenkins"
    echo "  • Installs Docker, AWS CLI, SAM CLI"
    echo "  • Configures security groups"
    echo "  • Returns Jenkins admin password"
    exit 1
fi

AWS_REGION="${PIPELINE_AWS_REGION:-${AWS_REGION:-us-east-1}}"
# Default to a roomier instance; override with INSTANCE_TYPE env if desired
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.medium}"
INSTANCE_NAME="jenkins-ci-cd-${ENVIRONMENT}"
SECURITY_GROUP_NAME="jenkins-ec2-sg-${ENVIRONMENT}"
KEY_NAME="${KEY_NAME:-vockey}"

################################################################################
# Introduction
################################################################################

show_introduction() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       PHASE 5: JENKINS EC2 SETUP                               ║${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}║  Deploy CI/CD automation server on AWS                        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_header "What is AWS EC2?"

    print_info "EC2 (Elastic Compute Cloud) provides virtual servers in AWS:"
    print_info "  • Like renting a computer in AWS's data center"
    print_info "  • Choose CPU, memory, storage (instance type)"
    print_info "  • Full control: install any software, run any workload"
    print_info "  • Pay per hour (can stop to save money)"
    print_info "  • Scales up/down as needed"
    echo ""

    print_info "EC2 Instance Types:"
    print_info "  • t2.micro: 1 vCPU, 1GB RAM (~$0.012/hr) - Free tier"
    print_info "  • t3.medium: 2 vCPU, 4GB RAM (~$0.0416/hr) - Default for Jenkins"
    print_info "  • t3.large: 2 vCPU, 8GB RAM (~$0.0832/hr) - Heavier builds"
    print_info "  • m5.large: 2 vCPU, 8GB RAM (~$0.096/hr) - Production"
    echo ""

    print_header "Why Jenkins on EC2?"

    print_info "Benefits of running Jenkins on EC2:"
    print_info "  • Dedicated CI/CD server (always available for webhooks)"
    print_info "  • AWS integration (IAM roles, no credentials needed)"
    print_info "  • Scalable (can upgrade instance type if needed)"
    print_info "  • Cost-effective (stop when not in use)"
    print_info "  • Persistent storage (EBS volumes)"
    echo ""

    print_info "Configuration:"
    echo -e "  ${BLUE}Environment:${NC}       $ENVIRONMENT"
    echo -e "  ${BLUE}Instance Type:${NC}     $INSTANCE_TYPE (recommended: t3.medium 2 vCPU, 4GB RAM)"
    echo -e "  ${BLUE}Instance Name:${NC}     $INSTANCE_NAME"
    echo -e "  ${BLUE}Region:${NC}            $AWS_REGION"
    echo -e "  ${BLUE}Key Pair:${NC}          $KEY_NAME"
    echo ""
}

################################################################################
# Current script continues with all existing functionality...
# The rest of the script remains exactly as it was, preserving all logic
################################################################################

# Step 1: Check prerequisites
check_prerequisites() {
    print_header "Step 1: Checking Prerequisites"

    print_info "Validating AWS environment and credentials..."
    echo ""

    # Check AWS CLI
    print_info "Checking AWS CLI..."
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found"
        echo ""
        print_info "Install AWS CLI:"
        print_command "curl 'https://awscli.amazonaws.com/AWSCLIV2.pkg' -o 'AWSCLIV2.pkg'"
        print_command "sudo installer -pkg AWSCLIV2.pkg -target /"
        exit 1
    fi

    print_success "AWS CLI found: $(aws --version)"
    echo ""

    # Check AWS credentials
    print_info "Validating AWS credentials..."
    print_explain "This calls AWS STS to verify your credentials work"
    echo ""

    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured or expired"
        echo ""
        print_info "For AWS Learner Lab:"
        print_info "  1. Open Learner Lab → Start Lab"
        print_info "  2. Click 'AWS Details' → Show AWS CLI credentials"
        print_info "  3. Copy credentials to ~/.aws/credentials"
        exit 1
    fi

    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    print_success "AWS credentials validated"
    print_info "Account ID: $AWS_ACCOUNT_ID"
    echo ""

    # Check key pair
    print_info "Checking EC2 key pair..."
    print_explain "Key pairs are used for SSH access to EC2 instances"
    print_explain "Default in Learner Lab: 'vockey'"
    echo ""

    if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" &> /dev/null; then
        print_error "EC2 key pair '$KEY_NAME' not found in region $AWS_REGION"
        echo ""
        print_info "Available key pairs:"
        aws ec2 describe-key-pairs --region "$AWS_REGION" --query 'KeyPairs[*].KeyName' --output table
        echo ""
        print_info "Set different key pair:"
        print_command "export KEY_NAME=your-key-name"
        print_command "$0 $1"
        exit 1
    fi

    print_success "EC2 key pair '$KEY_NAME' found"
    echo ""
}

create_security_group() {
    print_header "Step 2: Creating Security Group"

    print_info "What is a Security Group?"
    print_info "  • Acts as a virtual firewall for EC2 instances"
    print_info "  • Controls inbound and outbound traffic"
    print_info "  • Stateful (return traffic automatically allowed)"
    print_info "  • Can be reused across multiple instances"
    echo ""

    print_info "Ports needed for Jenkins:"
    print_info "  • Port 22 (SSH): Remote access to EC2 instance"
    print_info "  • Port 8080 (Jenkins): Web UI and webhook endpoint"
    print_info "  • Port 443 (HTTPS): Optional SSL termination"
    echo ""

    # Check if security group already exists
    SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
        --region "$AWS_REGION" \
        --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null || echo "None")

    if [ "$SECURITY_GROUP_ID" == "None" ] || [ -z "$SECURITY_GROUP_ID" ]; then
        print_info "Creating new security group: $SECURITY_GROUP_NAME"
        echo ""

        # Get default VPC
        print_info "Finding default VPC..."
        print_explain "VPC (Virtual Private Cloud) is your isolated network in AWS"
        echo ""

        VPC_ID=$(aws ec2 describe-vpcs \
            --region "$AWS_REGION" \
            --filters "Name=isDefault,Values=true" \
            --query 'Vpcs[0].VpcId' \
            --output text)

        if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
            print_error "No default VPC found in region $AWS_REGION"
            exit 1
        fi

        print_success "Using VPC: $VPC_ID"
        echo ""

        # Create security group
        print_info "Creating security group..."
        SECURITY_GROUP_ID=$(aws ec2 create-security-group \
            --region "$AWS_REGION" \
            --group-name "$SECURITY_GROUP_NAME" \
            --description "Security group for Jenkins CI/CD server ($ENVIRONMENT)" \
            --vpc-id "$VPC_ID" \
            --query 'GroupId' \
            --output text)

        print_success "Security group created: $SECURITY_GROUP_ID"
        echo ""

        # Add inbound rules
        print_info "Adding inbound rules..."
        echo ""

        print_info "Rule 1: SSH (port 22) from anywhere"
        print_explain "  Allows: ssh -i key.pem ec2-user@<ip>"
        aws ec2 authorize-security-group-ingress \
            --region "$AWS_REGION" \
            --group-id "$SECURITY_GROUP_ID" \
            --protocol tcp \
            --port 22 \
            --cidr 0.0.0.0/0 \
            --output text > /dev/null

        print_info "Rule 2: Jenkins (port 8080) from anywhere"
        print_explain "  Allows: http://<ip>:8080 (Jenkins UI and webhooks)"
        aws ec2 authorize-security-group-ingress \
            --region "$AWS_REGION" \
            --group-id "$SECURITY_GROUP_ID" \
            --protocol tcp \
            --port 8080 \
            --cidr 0.0.0.0/0 \
            --output text > /dev/null

        print_info "Rule 3: HTTPS (port 443) from anywhere"
        print_explain "  Allows: https://<ip> (optional SSL)"
        aws ec2 authorize-security-group-ingress \
            --region "$AWS_REGION" \
            --group-id "$SECURITY_GROUP_ID" \
            --protocol tcp \
            --port 443 \
            --cidr 0.0.0.0/0 \
            --output text > /dev/null

        echo ""
        print_success "Security group configured with ports: 22, 8080, 443"
    else
        print_success "Using existing security group: $SECURITY_GROUP_ID"
    fi

    echo ""
}

get_ami() {
    print_header "Step 3: Finding Amazon Linux 2023 AMI"

    print_info "What is an AMI (Amazon Machine Image)?"
    print_info "  • Template for EC2 instances (like a disk image)"
    print_info "  • Contains OS, software, configuration"
    print_info "  • AWS provides official AMIs (Amazon Linux, Ubuntu, etc.)"
    print_info "  • Can create custom AMIs with pre-installed software"
    echo ""

    print_info "Why Amazon Linux 2023?"
    print_info "  • Optimized for AWS (better performance)"
    print_info "  • Long-term support (LTS)"
    print_info "  • Pre-configured with AWS tools"
    print_info "  • Uses dnf package manager (modern)"
    echo ""

    print_info "Querying latest AMI..."
    print_command "aws ec2 describe-images \\"
    print_command "    --owners amazon \\"
    print_command "    --filters 'Name=name,Values=al2023-ami-2023.*-x86_64' \\"
    print_command "    --query 'sort_by(Images, &CreationDate)[-1].ImageId'"
    echo ""

    AMI_ID=$(aws ec2 describe-images \
        --region "$AWS_REGION" \
        --owners amazon \
        --filters "Name=name,Values=al2023-ami-2023.*-x86_64" \
                  "Name=state,Values=available" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --output text)

    if [ -z "$AMI_ID" ] || [ "$AMI_ID" == "None" ]; then
        print_error "Could not find Amazon Linux 2023 AMI"
        exit 1
    fi

    print_success "Found AMI: $AMI_ID"
    print_info "This is the latest Amazon Linux 2023 image"
    echo ""
}

prepare_user_data() {
    print_header "Step 4: Preparing User Data Script"

    print_info "What is User Data?"
    print_info "  • Script that runs on first boot of EC2 instance"
    print_info "  • Executes as root user"
    print_info "  • Used for automated installation and configuration"
    print_info "  • Logs saved to /var/log/cloud-init-output.log"
    echo ""

    print_info "This script will install:"
    print_info "  • Java 17 (Jenkins requirement)"
    print_info "  • Jenkins LTS (latest stable version)"
    print_info "  • Docker (for building container images)"
    print_info "  • AWS CLI v2 (for ECR, SAM, etc.)"
    print_info "  • SAM CLI (for Lambda deployments)"
    print_info "  • Git (for cloning repositories)"
    print_info "  • Python 3.11 + pytest (for test execution)"
    echo ""

    print_info "Generating User Data script..."
    echo ""

    cat > /tmp/jenkins-userdata.sh << 'USERDATA_EOF'
#!/bin/bash
# Jenkins EC2 User Data Script
# Installs: Java 17, Jenkins LTS, Docker, AWS CLI v2, SAM CLI, Git, Python 3.11

set -e

LOG_FILE="/var/log/jenkins-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================"
echo "Jenkins EC2 Setup - Starting Installation"
echo "Date: $(date)"
echo "============================================"

# Update system
echo "Updating system packages..."
dnf update -y

# Install Java 17 (Jenkins requirement)
echo "Installing Java 17..."
dnf install -y java-17-amazon-corretto-devel
java -version

# Install Jenkins LTS
echo "Installing Jenkins LTS..."
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins

# Start Jenkins service
echo "Starting Jenkins service..."
systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

# Wait for Jenkins to create initial admin password file
echo "Waiting for Jenkins to initialize..."
for i in {1..30}; do
    if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
        echo "Jenkins initialized successfully"
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 10
done

# Install Docker
echo "Installing Docker..."
dnf install -y docker
systemctl enable docker
systemctl start docker

# Add jenkins and ec2-user to docker group
usermod -aG docker jenkins
usermod -aG docker ec2-user

# Restart Jenkins to apply docker group membership
systemctl restart jenkins

# Install AWS CLI v2
echo "Installing AWS CLI v2..."
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
dnf install -y unzip
unzip -q awscliv2.zip
./aws/install
aws --version

# Install SAM CLI
echo "Installing AWS SAM CLI..."
wget -q https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip
unzip -q aws-sam-cli-linux-x86_64.zip -d sam-installation
./sam-installation/install
sam --version

# Install Git
echo "Installing Git..."
dnf install -y git
git --version

# Install Python 3.11
echo "Installing Python 3.11..."
dnf install -y python3.11 python3.11-pip python3.11-devel
python3.11 --version

# Install pytest (for CI pipeline)
python3.11 -m pip install pytest

# Clean up
echo "Cleaning up temporary files..."
rm -rf /tmp/awscliv2.zip /tmp/aws /tmp/aws-sam-cli-linux-x86_64.zip /tmp/sam-installation

echo "============================================"
echo "Jenkins EC2 Setup - Installation Complete"
echo "Date: $(date)"
echo "============================================"
echo ""
echo "Installed software versions:"
echo "- Java: $(java -version 2>&1 | head -1)"
echo "- Jenkins: $(systemctl is-active jenkins)"
echo "- Docker: $(docker --version)"
echo "- AWS CLI: $(aws --version)"
echo "- SAM CLI: $(sam --version)"
echo "- Git: $(git --version)"
echo "- Python: $(python3.11 --version)"
echo ""
echo "Jenkins initial admin password:"
cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "Not yet available"
echo ""
echo "Setup log saved to: $LOG_FILE"
USERDATA_EOF

    print_success "User Data script prepared"
    print_info "Script location: /tmp/jenkins-userdata.sh"
    echo ""
}

launch_instance() {
    print_header "Step 5: Launching EC2 Instance"

    # Check for existing instance
    print_info "Checking for existing instance..."
    EXISTING_INSTANCE=$(aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=$INSTANCE_NAME" \
                  "Name=instance-state-name,Values=running,pending,stopped,stopping" \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text 2>/dev/null || echo "None")

    if [ "$EXISTING_INSTANCE" != "None" ] && [ -n "$EXISTING_INSTANCE" ]; then
        print_warning "Instance '$INSTANCE_NAME' already exists: $EXISTING_INSTANCE"

        INSTANCE_STATE=$(aws ec2 describe-instances \
            --region "$AWS_REGION" \
            --instance-ids "$EXISTING_INSTANCE" \
            --query 'Reservations[0].Instances[0].State.Name' \
            --output text)

        print_info "Current state: $INSTANCE_STATE"
        echo ""

        if [ "$INSTANCE_STATE" == "stopped" ]; then
            echo "Would you like to start this instance instead? (yes/no)"
            read -r RESPONSE
            if [ "$RESPONSE" == "yes" ]; then
                print_info "Starting instance..."
                aws ec2 start-instances --region "$AWS_REGION" --instance-ids "$EXISTING_INSTANCE"
                INSTANCE_ID="$EXISTING_INSTANCE"
            else
                print_info "Exiting. Terminate existing instance first or use different --environment"
                exit 1
            fi
        elif [ "$INSTANCE_STATE" == "running" ]; then
            print_info "Using existing running instance"
            INSTANCE_ID="$EXISTING_INSTANCE"
        else
            print_error "Instance in transitional state. Wait or terminate it."
            exit 1
        fi
    else
        # Get IAM instance profile
        print_info "Looking for IAM instance profile (LabInstanceProfile)..."
        print_explain "Instance profiles allow EC2 to assume IAM roles"
        print_explain "This gives Jenkins AWS API access without credentials"
        echo ""

        INSTANCE_PROFILE_ARN=$(aws iam list-instance-profiles \
            --query "InstanceProfiles[?contains(InstanceProfileName, 'LabInstanceProfile')].Arn | [0]" \
            --output text 2>/dev/null || echo "")

        if [ -z "$INSTANCE_PROFILE_ARN" ] || [ "$INSTANCE_PROFILE_ARN" == "None" ]; then
            print_warning "LabInstanceProfile not found"
            print_info "Instance will launch without IAM role"
            print_info "You'll need to configure AWS credentials in Jenkins manually"
            INSTANCE_PROFILE_PARAM=""
        else
            print_success "Found IAM instance profile: $INSTANCE_PROFILE_ARN"
            INSTANCE_PROFILE_PARAM="--iam-instance-profile Arn=$INSTANCE_PROFILE_ARN"
        fi

        echo ""
        print_info "Launching EC2 instance..."
        print_command "aws ec2 run-instances \\"
        print_command "    --image-id $AMI_ID \\"
        print_command "    --instance-type $INSTANCE_TYPE \\"
        print_command "    --key-name $KEY_NAME \\"
        print_command "    --security-group-ids $SECURITY_GROUP_ID \\"
        print_command "    --user-data file:///tmp/jenkins-userdata.sh"
        echo ""

        print_explain "Parameters:"
        print_explain "  • --instance-type t3.medium: 2 vCPU, 4GB RAM, ~$0.0416/hr (default)"
        print_explain "  • --block-device-mappings: 20GB gp3 SSD ($2/month)"
        print_explain "  • --user-data: Runs installation script on first boot"
        echo ""

        INSTANCE_ID=$(aws ec2 run-instances \
            --region "$AWS_REGION" \
            --image-id "$AMI_ID" \
            --instance-type "$INSTANCE_TYPE" \
            --key-name "$KEY_NAME" \
            --security-group-ids "$SECURITY_GROUP_ID" \
            $INSTANCE_PROFILE_PARAM \
            --user-data file:///tmp/jenkins-userdata.sh \
            --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":20,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=Environment,Value=$ENVIRONMENT},{Key=Purpose,Value=Jenkins-CI-CD}]" \
            --query 'Instances[0].InstanceId' \
            --output text)

        if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "None" ]; then
            print_error "Failed to launch EC2 instance"
            exit 1
        fi

        print_success "Instance launched: $INSTANCE_ID"
    fi

    echo ""
}

wait_for_instance() {
    print_header "Step 6: Waiting for Instance"

    print_info "Waiting for instance to reach 'running' state..."
    print_info "This usually takes 30-60 seconds..."
    echo ""

    aws ec2 wait instance-running --region "$AWS_REGION" --instance-ids "$INSTANCE_ID"

    print_success "Instance is running"
    echo ""

    # Get instance details
    INSTANCE_INFO=$(aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0]')

    PUBLIC_IP=$(echo "$INSTANCE_INFO" | jq -r '.PublicIpAddress')
    PRIVATE_IP=$(echo "$INSTANCE_INFO" | jq -r '.PrivateIpAddress')
    AVAILABILITY_ZONE=$(echo "$INSTANCE_INFO" | jq -r '.Placement.AvailabilityZone')

    print_info "Instance Details:"
    echo -e "    ${BLUE}Instance ID:${NC}        $INSTANCE_ID"
    echo -e "    ${BLUE}Public IP:${NC}          $PUBLIC_IP"
    echo -e "    ${BLUE}Private IP:${NC}         $PRIVATE_IP"
    echo -e "    ${BLUE}Availability Zone:${NC}  $AVAILABILITY_ZONE"
    echo -e "    ${BLUE}Security Group:${NC}     $SECURITY_GROUP_ID"
    echo ""
}

wait_for_jenkins() {
    print_header "Step 7: Waiting for Jenkins Initialization"

    print_info "The User Data script is now running on the EC2 instance"
    print_info "This process takes 5-10 minutes and includes:"
    print_info "  • System package updates"
    print_info "  • Java 17 installation"
    print_info "  • Jenkins LTS installation and startup"
    print_info "  • Docker installation"
    print_info "  • AWS CLI v2 and SAM CLI installation"
    print_info "  • Python 3.11 and pytest installation"
    echo ""

    print_info "Checking Jenkins availability..."
    echo ""

    JENKINS_READY=false
    MAX_ATTEMPTS=60
    ATTEMPT=0

    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        ATTEMPT=$((ATTEMPT + 1))

        # Check if Jenkins port is accessible
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$PUBLIC_IP:8080" 2>/dev/null || echo "000")

        if echo "$HTTP_CODE" | grep -q "200\|403"; then
            print_success "Jenkins web interface is accessible (HTTP $HTTP_CODE)"
            JENKINS_READY=true
            break
        fi

        if [ $((ATTEMPT % 4)) -eq 0 ]; then
            print_info "Still waiting for Jenkins... ($ATTEMPT/$MAX_ATTEMPTS attempts)"
        fi
        sleep 15
    done

    if [ "$JENKINS_READY" = false ]; then
        print_warning "Jenkins is taking longer than expected"
        echo ""
        print_info "The User Data script may still be running. You can:"
        print_info "  1. Wait a few more minutes and check: http://$PUBLIC_IP:8080"
        print_info "  2. SSH in to check progress:"
        print_command "ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@$PUBLIC_IP"
        print_command "sudo tail -f /var/log/jenkins-setup.log"
    fi

    echo ""
}

retrieve_password() {
    print_header "Step 8: Retrieving Jenkins Admin Password"

    print_info "Jenkins generates a random admin password on first startup"
    print_info "Location: /var/lib/jenkins/secrets/initialAdminPassword"
    echo ""

    if [ "$JENKINS_READY" = true ]; then
        print_info "Attempting SSH retrieval..."
        echo ""

        INITIAL_PASSWORD=$(ssh -i ~/.ssh/${KEY_NAME}.pem \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o LogLevel=ERROR \
            ec2-user@$PUBLIC_IP \
            "sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null" || echo "")

        if [ -n "$INITIAL_PASSWORD" ]; then
            print_success "Jenkins admin password retrieved"
        else
            print_warning "Could not retrieve password automatically"
            echo ""
            print_info "Possible reasons:"
            print_info "  • SSH key not at ~/.ssh/${KEY_NAME}.pem"
            print_info "  • Jenkins still initializing"
            print_info "  • SSH permissions issue"
            INITIAL_PASSWORD=""
        fi
    else
        INITIAL_PASSWORD=""
    fi

    echo ""
}

save_info() {
    print_header "Step 9: Saving Instance Information"

    INSTANCE_INFO_FILE="$PROJECT_ROOT/.jenkins-ec2-$ENVIRONMENT.info"

    cat > "$INSTANCE_INFO_FILE" << EOF
# Jenkins EC2 Instance Information
# Environment: $ENVIRONMENT
# Created: $(date)

INSTANCE_ID=$INSTANCE_ID
PUBLIC_IP=$PUBLIC_IP
PRIVATE_IP=$PRIVATE_IP
REGION=$AWS_REGION
SECURITY_GROUP_ID=$SECURITY_GROUP_ID
KEY_NAME=$KEY_NAME
INITIAL_PASSWORD=$INITIAL_PASSWORD
EOF

    print_success "Instance information saved"
    print_info "File: $INSTANCE_INFO_FILE"
    echo ""

    # Clean up
    rm -f /tmp/jenkins-userdata.sh
}

display_summary() {
    print_header "Phase 5: Jenkins EC2 Setup Complete ✅"

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       JENKINS CI/CD SERVER DEPLOYED! ✓                       ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_info "Instance Information:"
    echo -e "    ${BLUE}Instance ID:${NC}  $INSTANCE_ID"
    echo -e "    ${BLUE}Public IP:${NC}    $PUBLIC_IP"
    echo -e "    ${BLUE}Region:${NC}       $AWS_REGION"
    echo ""

    print_info "Jenkins Access:"
    echo -e "    ${BLUE}URL:${NC}          ${GREEN}http://$PUBLIC_IP:8080${NC}"
    if [ -n "$INITIAL_PASSWORD" ]; then
        echo -e "    ${BLUE}Password:${NC}     ${YELLOW}$INITIAL_PASSWORD${NC}"
    else
        echo -e "    ${BLUE}Password:${NC}     (retrieve manually - see below)"
    fi
    echo ""

    print_info "SSH Access:"
    print_command "ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
    echo ""

    print_header "Next Steps"

    print_info "1. Open Jenkins in browser:"
    print_command "open http://$PUBLIC_IP:8080"
    echo ""

    print_info "2. Enter initial admin password (shown above or retrieve with):"
    if [ -z "$INITIAL_PASSWORD" ]; then
        print_command "ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
        print_command "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
        echo ""
    fi

    print_info "3. Install suggested plugins"
    echo ""

    print_info "4. Create admin user"
    echo ""

    print_info "5. Configure Jenkins jobs:"
    print_command "./scripts/jenkins/42-configure-jenkins-jobs.sh --$ENVIRONMENT"
    echo ""

    print_header "Cost Management"

    print_info "Monthly costs:"
    print_info "  • Running 24/7: ~\$17 (EC2) + \$2 (EBS) = \$19/month"
    print_info "  • Running 8hrs/day: ~\$6 (EC2) + \$2 (EBS) = \$8/month"
    print_info "  • Stopped: \$0 (EC2) + \$2 (EBS) = \$2/month"
    echo ""

    print_info "To stop instance (save \$17/month):"
    print_command "./scripts/jenkins/94-stop-jenkins-ec2.sh --$ENVIRONMENT"
    echo ""

    print_info "To start instance:"
    print_command "./scripts/jenkins/93-start-jenkins-ec2.sh --$ENVIRONMENT"
    echo ""

    print_header "Troubleshooting"

    print_info "View setup logs:"
    print_command "ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
    print_command "sudo tail -f /var/log/jenkins-setup.log"
    echo ""

    print_info "Check Jenkins status:"
    print_command "sudo systemctl status jenkins"
    echo ""

    print_info "Restart Jenkins:"
    print_command "sudo systemctl restart jenkins"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    show_introduction
    check_prerequisites
    create_security_group
    get_ami
    prepare_user_data
    launch_instance
    wait_for_instance
    wait_for_jenkins
    retrieve_password
    save_info
    display_summary

    print_success "Jenkins EC2 setup complete!"
    echo ""
}

# Run main function
main "$@"
