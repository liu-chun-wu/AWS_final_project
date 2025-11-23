#!/bin/bash
# Script: 40-setup-jenkins-ec2.sh
# Purpose: Launch and configure Jenkins on AWS EC2 for CI/CD automation
# Usage: ./40-setup-jenkins-ec2.sh [--demo|--prod]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parse arguments
ENVIRONMENT=""
if [ "$1" == "--demo" ]; then
    ENVIRONMENT="demo"
elif [ "$1" == "--prod" ]; then
    ENVIRONMENT="prod"
else
    echo "Usage: $0 [--demo|--prod]"
    echo "  --demo  Setup Jenkins for demo environment"
    echo "  --prod  Setup Jenkins for production environment"
    exit 1
fi

AWS_REGION="${AWS_REGION:-us-east-1}"
INSTANCE_TYPE="t2.small"
INSTANCE_NAME="jenkins-ci-cd-${ENVIRONMENT}"
SECURITY_GROUP_NAME="jenkins-ec2-sg-${ENVIRONMENT}"
KEY_NAME="${KEY_NAME:-vockey}"  # AWS Learner Lab default key pair

echo "============================================"
echo "Phase 5: Jenkins EC2 Setup"
echo "============================================"
echo "Environment: $ENVIRONMENT"
echo "Instance Type: $INSTANCE_TYPE"
echo "Region: $AWS_REGION"
echo ""

# Step 1: Check prerequisites
echo "Step 1: Checking prerequisites..."
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install AWS CLI first."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured or expired."
    echo "   Run: aws configure"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✅ AWS credentials validated"
echo "   Account ID: $AWS_ACCOUNT_ID"
echo ""

# Check if key pair exists
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" &> /dev/null; then
    echo "❌ EC2 key pair '$KEY_NAME' not found in region $AWS_REGION"
    echo "   Available key pairs:"
    aws ec2 describe-key-pairs --region "$AWS_REGION" --query 'KeyPairs[*].KeyName' --output table
    echo ""
    echo "   Create a key pair or set KEY_NAME environment variable:"
    echo "   export KEY_NAME=your-key-name"
    exit 1
fi

echo "✅ EC2 key pair '$KEY_NAME' found"
echo ""

# Step 2: Create Security Group
echo "Step 2: Creating security group..."
echo ""

# Check if security group already exists
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
    --region "$AWS_REGION" \
    --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || echo "None")

if [ "$SECURITY_GROUP_ID" == "None" ] || [ -z "$SECURITY_GROUP_ID" ]; then
    echo "Creating new security group: $SECURITY_GROUP_NAME"

    # Get default VPC ID
    VPC_ID=$(aws ec2 describe-vpcs \
        --region "$AWS_REGION" \
        --filters "Name=isDefault,Values=true" \
        --query 'Vpcs[0].VpcId' \
        --output text)

    if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
        echo "❌ No default VPC found in region $AWS_REGION"
        exit 1
    fi

    echo "Using VPC: $VPC_ID"

    # Create security group
    SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --region "$AWS_REGION" \
        --group-name "$SECURITY_GROUP_NAME" \
        --description "Security group for Jenkins CI/CD server ($ENVIRONMENT)" \
        --vpc-id "$VPC_ID" \
        --query 'GroupId' \
        --output text)

    echo "Security group created: $SECURITY_GROUP_ID"

    # Add inbound rules
    echo "Adding inbound rules..."

    # SSH (port 22)
    aws ec2 authorize-security-group-ingress \
        --region "$AWS_REGION" \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --output text > /dev/null

    # Jenkins (port 8080)
    aws ec2 authorize-security-group-ingress \
        --region "$AWS_REGION" \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol tcp \
        --port 8080 \
        --cidr 0.0.0.0/0 \
        --output text > /dev/null

    # HTTPS (port 443)
    aws ec2 authorize-security-group-ingress \
        --region "$AWS_REGION" \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol tcp \
        --port 443 \
        --cidr 0.0.0.0/0 \
        --output text > /dev/null

    echo "✅ Security group configured with ports: 22 (SSH), 8080 (Jenkins), 443 (HTTPS)"
else
    echo "✅ Using existing security group: $SECURITY_GROUP_ID"
fi

echo ""

# Step 3: Get latest Amazon Linux 2023 AMI
echo "Step 3: Finding latest Amazon Linux 2023 AMI..."
echo ""

AMI_ID=$(aws ec2 describe-images \
    --region "$AWS_REGION" \
    --owners amazon \
    --filters "Name=name,Values=al2023-ami-2023.*-x86_64" \
              "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text)

if [ -z "$AMI_ID" ] || [ "$AMI_ID" == "None" ]; then
    echo "❌ Could not find Amazon Linux 2023 AMI"
    exit 1
fi

echo "✅ Found AMI: $AMI_ID"
echo ""

# Step 4: Create User Data script for Jenkins installation
echo "Step 4: Preparing Jenkins installation script..."
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

echo "✅ User Data script prepared"
echo ""

# Step 5: Launch EC2 instance
echo "Step 5: Launching EC2 instance..."
echo ""

# Check for existing instance
EXISTING_INSTANCE=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=$INSTANCE_NAME" \
              "Name=instance-state-name,Values=running,pending,stopped,stopping" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || echo "None")

if [ "$EXISTING_INSTANCE" != "None" ] && [ -n "$EXISTING_INSTANCE" ]; then
    echo "⚠️  Instance with name '$INSTANCE_NAME' already exists: $EXISTING_INSTANCE"
    INSTANCE_STATE=$(aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --instance-ids "$EXISTING_INSTANCE" \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text)

    echo "   Current state: $INSTANCE_STATE"
    echo ""

    if [ "$INSTANCE_STATE" == "stopped" ]; then
        echo "Would you like to start this instance instead? (yes/no)"
        read -r RESPONSE
        if [ "$RESPONSE" == "yes" ]; then
            echo "Starting instance $EXISTING_INSTANCE..."
            aws ec2 start-instances --region "$AWS_REGION" --instance-ids "$EXISTING_INSTANCE"
            INSTANCE_ID="$EXISTING_INSTANCE"
        else
            echo "Exiting. Please terminate or rename the existing instance first."
            exit 1
        fi
    elif [ "$INSTANCE_STATE" == "running" ]; then
        echo "Instance is already running. Using existing instance."
        INSTANCE_ID="$EXISTING_INSTANCE"
    else
        echo "Exiting. Please wait for the instance to reach a stable state or terminate it."
        exit 1
    fi
else
    # Get IAM instance profile ARN (LabRole for AWS Learner Lab)
    INSTANCE_PROFILE_ARN=$(aws iam list-instance-profiles \
        --query "InstanceProfiles[?contains(InstanceProfileName, 'LabInstanceProfile')].Arn | [0]" \
        --output text 2>/dev/null || echo "")

    if [ -z "$INSTANCE_PROFILE_ARN" ] || [ "$INSTANCE_PROFILE_ARN" == "None" ]; then
        echo "⚠️  LabInstanceProfile not found. Instance will launch without IAM role."
        echo "   You may need to configure AWS credentials manually in Jenkins."
        INSTANCE_PROFILE_PARAM=""
    else
        echo "✅ Found IAM instance profile: $INSTANCE_PROFILE_ARN"
        INSTANCE_PROFILE_PARAM="--iam-instance-profile Arn=$INSTANCE_PROFILE_ARN"
    fi

    echo "Launching EC2 instance..."
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
        echo "❌ Failed to launch EC2 instance"
        exit 1
    fi

    echo "✅ Instance launched: $INSTANCE_ID"
fi

echo ""

# Step 6: Wait for instance to be running
echo "Step 6: Waiting for instance to be running..."
echo "   This may take 2-3 minutes..."
echo ""

aws ec2 wait instance-running --region "$AWS_REGION" --instance-ids "$INSTANCE_ID"

echo "✅ Instance is running"
echo ""

# Get instance details
INSTANCE_INFO=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0]')

PUBLIC_IP=$(echo "$INSTANCE_INFO" | jq -r '.PublicIpAddress')
PRIVATE_IP=$(echo "$INSTANCE_INFO" | jq -r '.PrivateIpAddress')
AVAILABILITY_ZONE=$(echo "$INSTANCE_INFO" | jq -r '.Placement.AvailabilityZone')

echo "Instance Details:"
echo "  Instance ID: $INSTANCE_ID"
echo "  Public IP: $PUBLIC_IP"
echo "  Private IP: $PRIVATE_IP"
echo "  Availability Zone: $AVAILABILITY_ZONE"
echo "  Security Group: $SECURITY_GROUP_ID"
echo ""

# Step 7: Wait for Jenkins to be ready
echo "Step 7: Waiting for Jenkins to initialize..."
echo "   This may take 5-10 minutes for User Data script to complete..."
echo "   Jenkins service needs to start and generate initial admin password"
echo ""

JENKINS_READY=false
MAX_ATTEMPTS=60
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))

    # Check if Jenkins port is accessible
    if curl -s -o /dev/null -w "%{http_code}" "http://$PUBLIC_IP:8080" | grep -q "200\|403"; then
        echo "✅ Jenkins web interface is accessible"
        JENKINS_READY=true
        break
    fi

    echo "   Waiting for Jenkins... (attempt $ATTEMPT/$MAX_ATTEMPTS)"
    sleep 15
done

if [ "$JENKINS_READY" = false ]; then
    echo "⚠️  Jenkins is taking longer than expected to start"
    echo "   The User Data script may still be running"
    echo ""
    echo "You can:"
    echo "1. Wait a few more minutes and check manually: http://$PUBLIC_IP:8080"
    echo "2. SSH into the instance to check status:"
    echo "   ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@$PUBLIC_IP"
    echo "   sudo tail -f /var/log/jenkins-setup.log"
    echo "   sudo systemctl status jenkins"
fi

echo ""

# Step 8: Retrieve Jenkins initial admin password
echo "Step 8: Retrieving Jenkins initial admin password..."
echo ""

if [ "$JENKINS_READY" = true ]; then
    # Try to SSH and get the password
    echo "Attempting to retrieve password via SSH..."

    # Note: This requires SSH key to be available
    INITIAL_PASSWORD=$(ssh -i ~/.ssh/${KEY_NAME}.pem \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        ec2-user@$PUBLIC_IP \
        "sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null" || echo "")

    if [ -n "$INITIAL_PASSWORD" ]; then
        echo "✅ Jenkins initial admin password retrieved"
    else
        echo "⚠️  Could not retrieve password automatically"
        echo "   This may be because:"
        echo "   - SSH key not found at ~/.ssh/${KEY_NAME}.pem"
        echo "   - Jenkins is still initializing"
        echo "   - File permissions on the key"
    fi
else
    INITIAL_PASSWORD=""
fi

echo ""

# Step 9: Save instance information
echo "Step 9: Saving instance information..."
echo ""

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

echo "✅ Instance information saved to: $INSTANCE_INFO_FILE"
echo ""

# Clean up temporary files
rm -f /tmp/jenkins-userdata.sh

# Step 10: Display summary
echo "============================================"
echo "Phase 5: Jenkins EC2 Setup Complete ✅"
echo "============================================"
echo ""
echo "Instance Information:"
echo "  Instance ID: $INSTANCE_ID"
echo "  Public IP: $PUBLIC_IP"
echo "  Region: $AWS_REGION"
echo ""
echo "Jenkins Access:"
echo "  URL: http://$PUBLIC_IP:8080"
if [ -n "$INITIAL_PASSWORD" ]; then
    echo "  Initial Admin Password: $INITIAL_PASSWORD"
else
    echo "  Initial Admin Password: (retrieve manually - see instructions below)"
fi
echo ""
echo "SSH Access:"
echo "  ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
echo ""
echo "Next Steps:"
echo "1. Open Jenkins in browser: http://$PUBLIC_IP:8080"
echo "2. Enter the initial admin password shown above"
echo "3. Install suggested plugins (or select specific plugins)"
echo "4. Create your first admin user"
echo "5. Configure Jenkins URL to: http://$PUBLIC_IP:8080"
echo ""
if [ -z "$INITIAL_PASSWORD" ]; then
    echo "To retrieve initial password manually:"
    echo "  ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
    echo "  sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
    echo ""
fi
echo "To configure Jenkins jobs:"
echo "  ./scripts/aws-ci-cd/41-configure-jenkins-jobs.sh --$ENVIRONMENT"
echo ""
echo "Cost Estimate:"
echo "  EC2 t2.small: ~\$0.023/hour = ~\$17/month (24/7)"
echo "  EBS 20GB: ~\$2/month"
echo "  Total: ~\$19/month (or ~\$5-8/month if stopped when not in use)"
echo ""
echo "To stop instance when not in use:"
echo "  ./scripts/aws-ci-cd/94-stop-jenkins-ec2.sh --$ENVIRONMENT"
echo ""
echo "To start instance again:"
echo "  ./scripts/aws-ci-cd/93-start-jenkins-ec2.sh --$ENVIRONMENT"
echo ""
echo "Troubleshooting:"
echo "  View setup logs: ssh and run 'sudo tail -f /var/log/jenkins-setup.log'"
echo "  Check Jenkins status: sudo systemctl status jenkins"
echo "  Restart Jenkins: sudo systemctl restart jenkins"
echo "============================================"
