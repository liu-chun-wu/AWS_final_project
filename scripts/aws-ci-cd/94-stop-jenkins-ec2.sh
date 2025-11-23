#!/bin/bash
# Script: 94-stop-jenkins-ec2.sh
# Purpose: Stop Jenkins EC2 instance to save costs
# Usage: ./94-stop-jenkins-ec2.sh [--demo|--prod]

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
    echo "  --demo  Stop Jenkins demo instance"
    echo "  --prod  Stop Jenkins production instance"
    exit 1
fi

AWS_REGION="${AWS_REGION:-us-east-1}"

echo "============================================"
echo "Stop Jenkins EC2 Instance"
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
    exit 1
fi

echo "Current state: $INSTANCE_STATE"
echo ""

# Handle different states
case "$INSTANCE_STATE" in
    "stopped")
        echo "✅ Instance is already stopped"
        echo ""
        echo "To start the instance:"
        echo "  ./scripts/aws-ci-cd/93-start-jenkins-ec2.sh --$ENVIRONMENT"
        ;;

    "running")
        echo "⚠️  Stopping the instance will:"
        echo "  • Make Jenkins inaccessible"
        echo "  • Break GitHub webhooks (until restarted)"
        echo "  • Save ~\$0.023/hour (~\$0.55/day)"
        echo ""
        echo "⚠️  Note: Public IP will change when instance restarts"
        echo "  You will need to update GitHub webhook URL after restart"
        echo ""
        read -p "Are you sure you want to stop the instance? (yes/no): " CONFIRM

        if [ "$CONFIRM" != "yes" ]; then
            echo "Cancelled"
            exit 0
        fi

        echo ""
        echo "Stopping instance..."
        aws ec2 stop-instances \
            --region "$AWS_REGION" \
            --instance-ids "$INSTANCE_ID" \
            --output text > /dev/null

        echo "Waiting for instance to stop..."
        aws ec2 wait instance-stopped \
            --region "$AWS_REGION" \
            --instance-ids "$INSTANCE_ID"

        echo "✅ Instance stopped successfully"
        echo ""
        echo "Cost Savings:"
        echo "  EC2 charges stopped: ~\$0.023/hour saved"
        echo "  EBS charges continue: ~\$2/month (storage persists)"
        echo ""
        echo "To start the instance again:"
        echo "  ./scripts/aws-ci-cd/93-start-jenkins-ec2.sh --$ENVIRONMENT"
        echo ""
        echo "⚠️  When restarted, you will need to:"
        echo "  1. Note the new public IP address"
        echo "  2. Update GitHub webhook URL (if configured)"
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
echo "Cost Management Tips:"
echo "============================================"
echo ""
echo "When to stop:"
echo "  • End of work day (if not running overnight builds)"
echo "  • Weekends (if no CI/CD activity)"
echo "  • AWS Learner Lab session ends"
echo ""
echo "When to keep running:"
echo "  • Active development with frequent commits"
echo "  • GitHub webhooks configured for automatic builds"
echo "  • Debugging CI/CD pipeline issues"
echo ""
echo "Cost comparison:"
echo "  Running 24/7: ~\$17/month (EC2) + \$2/month (EBS) = \$19/month"
echo "  Running 8hrs/day: ~\$6/month (EC2) + \$2/month (EBS) = \$8/month"
echo "  Stopped: \$0/month (EC2) + \$2/month (EBS) = \$2/month"
echo ""
echo "Check instance status:"
echo "  ./scripts/aws-ci-cd/91-check-jenkins-status.sh --$ENVIRONMENT"
echo "============================================"
