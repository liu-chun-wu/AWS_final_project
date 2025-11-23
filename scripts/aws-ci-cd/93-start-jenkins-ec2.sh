#!/bin/bash
# Script: 93-start-jenkins-ec2.sh
# Purpose: Start a stopped Jenkins EC2 instance
# Usage: ./93-start-jenkins-ec2.sh [--demo|--prod]

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
    echo "  --demo  Start Jenkins demo instance"
    echo "  --prod  Start Jenkins production instance"
    exit 1
fi

AWS_REGION="${AWS_REGION:-us-east-1}"

echo "============================================"
echo "Start Jenkins EC2 Instance"
echo "============================================"
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo ""

# Load instance information
INSTANCE_INFO_FILE="$PROJECT_ROOT/.jenkins-ec2-$ENVIRONMENT.info"

if [ ! -f "$INSTANCE_INFO_FILE" ]; then
    echo "❌ Instance information file not found: $INSTANCE_INFO_FILE"
    echo ""
    echo "Please run 40-setup-jenkins-ec2.sh first:"
    echo "  ./scripts/aws-ci-cd/40-setup-jenkins-ec2.sh --$ENVIRONMENT"
    exit 1
fi

# Source the instance info
source "$INSTANCE_INFO_FILE"

if [ -z "$INSTANCE_ID" ]; then
    echo "❌ INSTANCE_ID not found in instance info file"
    exit 1
fi

echo "Instance ID: $INSTANCE_ID"
echo ""

# Check current instance state
echo "Checking instance state..."
INSTANCE_STATE=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text 2>/dev/null || echo "not-found")

if [ "$INSTANCE_STATE" == "not-found" ]; then
    echo "❌ Instance $INSTANCE_ID not found"
    echo "   The instance may have been terminated"
    echo ""
    echo "To create a new instance:"
    echo "  ./scripts/aws-ci-cd/40-setup-jenkins-ec2.sh --$ENVIRONMENT"
    exit 1
fi

echo "Current state: $INSTANCE_STATE"
echo ""

# Handle different states
case "$INSTANCE_STATE" in
    "running")
        echo "✅ Instance is already running"
        CURRENT_IP=$(aws ec2 describe-instances \
            --region "$AWS_REGION" \
            --instance-ids "$INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)

        echo "   Public IP: $CURRENT_IP"
        echo "   Jenkins URL: http://$CURRENT_IP:8080"
        echo ""

        # Check if IP has changed
        if [ "$CURRENT_IP" != "$PUBLIC_IP" ]; then
            echo "⚠️  Public IP has changed!"
            echo "   Old IP: $PUBLIC_IP"
            echo "   New IP: $CURRENT_IP"
            echo ""
            echo "Updating instance info file..."

            # Update the info file with new IP
            sed -i.bak "s|PUBLIC_IP=.*|PUBLIC_IP=$CURRENT_IP|g" "$INSTANCE_INFO_FILE"
            rm -f "$INSTANCE_INFO_FILE.bak"

            echo "✅ Info file updated"
            echo ""
            echo "⚠️  IMPORTANT: If using GitHub webhooks, update webhook URL:"
            echo "   New webhook URL: http://$CURRENT_IP:8080/github-webhook/"
            echo ""
        fi
        ;;

    "stopped")
        echo "Starting instance..."
        aws ec2 start-instances \
            --region "$AWS_REGION" \
            --instance-ids "$INSTANCE_ID" \
            --output text > /dev/null

        echo "Waiting for instance to start..."
        aws ec2 wait instance-running \
            --region "$AWS_REGION" \
            --instance-ids "$INSTANCE_ID"

        echo "✅ Instance started successfully"
        echo ""

        # Get new public IP
        NEW_PUBLIC_IP=$(aws ec2 describe-instances \
            --region "$AWS_REGION" \
            --instance-ids "$INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)

        echo "Instance Details:"
        echo "  Instance ID: $INSTANCE_ID"
        echo "  Public IP: $NEW_PUBLIC_IP"
        echo "  Jenkins URL: http://$NEW_PUBLIC_IP:8080"
        echo ""

        # Check if IP has changed
        if [ "$NEW_PUBLIC_IP" != "$PUBLIC_IP" ]; then
            echo "⚠️  Public IP has changed!"
            echo "   Old IP: $PUBLIC_IP"
            echo "   New IP: $NEW_PUBLIC_IP"
            echo ""
            echo "Updating instance info file..."

            # Update the info file with new IP
            sed -i.bak "s|PUBLIC_IP=.*|PUBLIC_IP=$NEW_PUBLIC_IP|g" "$INSTANCE_INFO_FILE"
            rm -f "$INSTANCE_INFO_FILE.bak"

            echo "✅ Info file updated"
            echo ""
            echo "⚠️  IMPORTANT: GitHub webhook URL has changed!"
            echo "   Update webhook in GitHub repository settings:"
            echo "   New webhook URL: http://$NEW_PUBLIC_IP:8080/github-webhook/"
            echo ""
        fi

        echo "Waiting for Jenkins service to be ready (30-60 seconds)..."
        sleep 30

        # Check if Jenkins is accessible
        MAX_ATTEMPTS=12
        for i in $(seq 1 $MAX_ATTEMPTS); do
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$NEW_PUBLIC_IP:8080" || echo "000")

            if echo "$HTTP_CODE" | grep -q "200\|403"; then
                echo "✅ Jenkins is accessible"
                break
            fi

            if [ $i -eq $MAX_ATTEMPTS ]; then
                echo "⚠️  Jenkins is taking longer than expected to start"
                echo "   Give it a few more minutes, then check:"
                echo "   http://$NEW_PUBLIC_IP:8080"
            else
                echo "   Waiting for Jenkins... ($i/$MAX_ATTEMPTS)"
                sleep 10
            fi
        done
        ;;

    "pending"|"stopping")
        echo "⚠️  Instance is in transitional state: $INSTANCE_STATE"
        echo "   Please wait for the instance to reach a stable state"
        echo "   Then run this script again"
        ;;

    "terminated")
        echo "❌ Instance has been terminated"
        echo ""
        echo "To create a new instance:"
        echo "  ./scripts/aws-ci-cd/40-setup-jenkins-ec2.sh --$ENVIRONMENT"
        exit 1
        ;;

    *)
        echo "❌ Unknown instance state: $INSTANCE_STATE"
        exit 1
        ;;
esac

echo ""
echo "============================================"
echo "Next Steps:"
echo "============================================"
echo ""
echo "Access Jenkins:"
FINAL_IP=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "  URL: http://$FINAL_IP:8080"
echo ""
echo "SSH to instance:"
echo "  ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$FINAL_IP"
echo ""
echo "Check Jenkins status:"
echo "  ./scripts/aws-ci-cd/91-check-jenkins-status.sh --$ENVIRONMENT"
echo ""
echo "Stop instance to save costs:"
echo "  ./scripts/aws-ci-cd/94-stop-jenkins-ec2.sh --$ENVIRONMENT"
echo ""
echo "Cost while running:"
echo "  EC2 t2.small: ~\$0.023/hour = ~\$0.55/day"
echo "============================================"
