#!/bin/bash
# Script: 91-check-jenkins-status.sh
# Purpose: Check Jenkins EC2 instance and service status
# Usage: ./91-check-jenkins-status.sh [--demo|--prod]

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
    echo "  --demo  Check Jenkins demo instance status"
    echo "  --prod  Check Jenkins production instance status"
    exit 1
fi

AWS_REGION="${AWS_REGION:-us-east-1}"

echo "============================================"
echo "Jenkins EC2 Status Check"
echo "============================================"
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo ""

# Load instance information
INSTANCE_INFO_FILE="$PROJECT_ROOT/.jenkins-ec2-$ENVIRONMENT.info"

if [ ! -f "$INSTANCE_INFO_FILE" ]; then
    echo "❌ Instance information file not found: $INSTANCE_INFO_FILE"
    echo ""
    echo "Jenkins EC2 instance has not been set up yet."
    echo ""
    echo "To set up Jenkins:"
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

# Get instance details
echo "Checking EC2 instance..."
INSTANCE_INFO=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0]' 2>/dev/null || echo "null")

if [ "$INSTANCE_INFO" == "null" ] || [ -z "$INSTANCE_INFO" ]; then
    echo "❌ Instance $INSTANCE_ID not found"
    echo "   The instance may have been terminated"
    echo ""
    echo "To create a new instance:"
    echo "  ./scripts/aws-ci-cd/40-setup-jenkins-ec2.sh --$ENVIRONMENT"
    exit 1
fi

# Parse instance details
INSTANCE_STATE=$(echo "$INSTANCE_INFO" | jq -r '.State.Name')
CURRENT_PUBLIC_IP=$(echo "$INSTANCE_INFO" | jq -r '.PublicIpAddress // "N/A"')
PRIVATE_IP=$(echo "$INSTANCE_INFO" | jq -r '.PrivateIpAddress // "N/A"')
INSTANCE_TYPE=$(echo "$INSTANCE_INFO" | jq -r '.InstanceType')
AVAILABILITY_ZONE=$(echo "$INSTANCE_INFO" | jq -r '.Placement.AvailabilityZone')
LAUNCH_TIME=$(echo "$INSTANCE_INFO" | jq -r '.LaunchTime')

# Display EC2 instance status
echo "============================================"
echo "EC2 Instance Status"
echo "============================================"
echo "  State: $INSTANCE_STATE"
echo "  Instance Type: $INSTANCE_TYPE"
echo "  Public IP: $CURRENT_PUBLIC_IP"
echo "  Private IP: $PRIVATE_IP"
echo "  Availability Zone: $AVAILABILITY_ZONE"
echo "  Launch Time: $LAUNCH_TIME"
echo ""

# Check if IP has changed
if [ "$CURRENT_PUBLIC_IP" != "$PUBLIC_IP" ] && [ "$CURRENT_PUBLIC_IP" != "N/A" ]; then
    echo "⚠️  Public IP has changed!"
    echo "  Stored IP: $PUBLIC_IP"
    echo "  Current IP: $CURRENT_PUBLIC_IP"
    echo ""
    echo "  Update instance info:"
    echo "    Run: ./scripts/aws-ci-cd/93-start-jenkins-ec2.sh --$ENVIRONMENT"
    echo ""
fi

# Check Jenkins accessibility if instance is running
if [ "$INSTANCE_STATE" == "running" ]; then
    echo "============================================"
    echo "Jenkins Service Status"
    echo "============================================"

    if [ "$CURRENT_PUBLIC_IP" == "N/A" ]; then
        echo "❌ No public IP assigned to instance"
    else
        JENKINS_URL="http://$CURRENT_PUBLIC_IP:8080"
        echo "  Jenkins URL: $JENKINS_URL"
        echo ""

        # Check Jenkins web interface
        echo "  Checking Jenkins web interface..."
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$JENKINS_URL" 2>/dev/null || echo "000")

        if echo "$HTTP_CODE" | grep -q "200\|403"; then
            echo "  ✅ Jenkins web interface: Accessible (HTTP $HTTP_CODE)"

            # Try to get Jenkins version
            JENKINS_VERSION=$(curl -s --connect-timeout 5 "$JENKINS_URL/api/json" 2>/dev/null | jq -r '.version // "unknown"' || echo "unknown")
            if [ "$JENKINS_VERSION" != "unknown" ]; then
                echo "  Jenkins version: $JENKINS_VERSION"
            fi
        else
            echo "  ❌ Jenkins web interface: Not accessible (HTTP $HTTP_CODE)"
            echo ""
            echo "  Possible reasons:"
            echo "    • Jenkins service is still starting (wait 2-3 minutes)"
            echo "    • Jenkins service crashed"
            echo "    • Security group misconfigured"
            echo ""
            echo "  Troubleshoot with SSH:"
            echo "    ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$CURRENT_PUBLIC_IP"
            echo "    sudo systemctl status jenkins"
            echo "    sudo journalctl -u jenkins -n 50"
        fi

        # Check for configured jobs
        echo ""
        echo "  Checking Jenkins jobs..."
        JOBS=$(curl -s --connect-timeout 5 "$JENKINS_URL/api/json?tree=jobs[name]" 2>/dev/null | jq -r '.jobs[]?.name' || echo "")

        if [ -n "$JOBS" ]; then
            echo "  Configured jobs:"
            echo "$JOBS" | while read -r job; do
                echo "    • $job"
            done
        else
            echo "  ⚠️  No jobs configured yet"
            echo "    Run: ./scripts/aws-ci-cd/41-configure-jenkins-jobs.sh --$ENVIRONMENT"
        fi
    fi

    echo ""
    echo "============================================"
    echo "Resource Utilization"
    echo "============================================"

    # Get CloudWatch metrics if available
    echo "  Checking CloudWatch metrics (last hour)..."

    CPU_AVG=$(aws cloudwatch get-metric-statistics \
        --region "$AWS_REGION" \
        --namespace AWS/EC2 \
        --metric-name CPUUtilization \
        --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
        --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:%M:%S)" \
        --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
        --period 3600 \
        --statistics Average \
        --query 'Datapoints[0].Average' \
        --output text 2>/dev/null || echo "N/A")

    if [ "$CPU_AVG" != "N/A" ] && [ "$CPU_AVG" != "None" ]; then
        printf "  CPU Utilization (avg): %.2f%%\n" "$CPU_AVG"
    else
        echo "  CPU Utilization: Data not available yet"
    fi

    echo ""
    echo "============================================"
    echo "Cost Information"
    echo "============================================"

    # Calculate running time
    if [ "$LAUNCH_TIME" != "null" ]; then
        LAUNCH_EPOCH=$(date -d "$LAUNCH_TIME" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo $LAUNCH_TIME | cut -d'.' -f1)" +%s)
        CURRENT_EPOCH=$(date +%s)
        RUNNING_HOURS=$(( (CURRENT_EPOCH - LAUNCH_EPOCH) / 3600 ))
        RUNNING_COST=$(echo "scale=2; $RUNNING_HOURS * 0.023" | bc)

        echo "  Running time: ~$RUNNING_HOURS hours"
        echo "  Estimated EC2 cost: \$$RUNNING_COST"
        echo "  Hourly rate: \$0.023/hour (t2.small)"
        echo "  Daily cost if running 24/7: ~\$0.55/day"
    fi

    echo ""

elif [ "$INSTANCE_STATE" == "stopped" ]; then
    echo "============================================"
    echo "Instance Status: STOPPED"
    echo "============================================"
    echo ""
    echo "The Jenkins instance is currently stopped."
    echo ""
    echo "Cost while stopped:"
    echo "  EC2 charges: \$0/hour (no charge when stopped)"
    echo "  EBS charges: ~\$2/month (storage persists)"
    echo ""
    echo "To start the instance:"
    echo "  ./scripts/aws-ci-cd/93-start-jenkins-ec2.sh --$ENVIRONMENT"
    echo ""
    echo "⚠️  Note: Public IP will change when instance restarts"
    echo ""

else
    echo "============================================"
    echo "Instance Status: $INSTANCE_STATE"
    echo "============================================"
    echo ""
    echo "The instance is in a transitional state."
    echo "Please wait for it to reach 'running' or 'stopped' state."
    echo ""
fi

# Summary and next steps
echo "============================================"
echo "Quick Actions"
echo "============================================"
echo ""

if [ "$INSTANCE_STATE" == "running" ]; then
    echo "Access Jenkins:"
    echo "  http://$CURRENT_PUBLIC_IP:8080"
    echo ""
    echo "SSH to instance:"
    echo "  ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$CURRENT_PUBLIC_IP"
    echo ""
    echo "View Jenkins logs:"
    echo "  ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$CURRENT_PUBLIC_IP 'sudo journalctl -u jenkins -f'"
    echo ""
    echo "Stop instance to save costs:"
    echo "  ./scripts/aws-ci-cd/94-stop-jenkins-ec2.sh --$ENVIRONMENT"
    echo ""
elif [ "$INSTANCE_STATE" == "stopped" ]; then
    echo "Start instance:"
    echo "  ./scripts/aws-ci-cd/93-start-jenkins-ec2.sh --$ENVIRONMENT"
    echo ""
fi

echo "View AWS resources:"
echo "  ./scripts/aws-ci-cd/90-check-aws-status.sh"
echo ""
echo "Configure Jenkins jobs:"
echo "  ./scripts/aws-ci-cd/41-configure-jenkins-jobs.sh --$ENVIRONMENT"
echo ""
echo "============================================"
