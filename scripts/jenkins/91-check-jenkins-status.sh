#!/bin/bash
################################################################################
# Script: 91-check-jenkins-status.sh
# Purpose: Check Jenkins EC2 instance and service status
# Usage: ./91-check-jenkins-status.sh [--demo|--prod]
#
################################################################################
# What is EC2 Instance Monitoring?
################################################################################
#
# This script provides comprehensive status checking for your Jenkins EC2
# instance, combining EC2 infrastructure monitoring with Jenkins service
# health checks. Think of it as a "health dashboard" for your CI/CD system.
#
# What is EC2 Instance State?
# ---------------------------
# EC2 instances have several lifecycle states:
#
# • pending: Instance is launching (typically 30-60 seconds)
# • running: Instance is active and accessible (you're charged for this)
# • stopping: Instance is shutting down (transitional state)
# • stopped: Instance is halted (no EC2 charges, but EBS storage still charged)
# • shutting-down: Instance is terminating (transitional state)
# • terminated: Instance is permanently deleted (all data lost)
#
# State Transitions:
# ------------------
# stopped → start → pending → running → stop → stopping → stopped
# running → terminate → shutting-down → terminated (irreversible!)
#
# What is monitored in this script?
# ----------------------------------
# 1. EC2 Infrastructure Layer:
#    • Instance state (running/stopped/terminated)
#    • Public IP address (changes when stopped/started!)
#    • Private IP address (stays constant within VPC)
#    • Instance type and specifications (t2.small)
#    • Availability zone (e.g., us-east-1a)
#    • Launch time and uptime
#
# 2. Network Layer:
#    • Public IP changes (warns if IP differs from stored value)
#    • Jenkins web interface accessibility (HTTP status codes)
#    • Port 8080 connectivity
#
# 3. Jenkins Application Layer:
#    • Jenkins service status (running or crashed)
#    • Jenkins version
#    • Configured jobs (CI/CD pipelines)
#
# 4. Performance Metrics (CloudWatch):
#    • CPU utilization (average over last hour)
#    • (Future: Memory, disk, network metrics)
#
# 5. Cost Tracking:
#    • Running time since launch
#    • Estimated EC2 costs
#    • Hourly and daily cost projections
#
# Why check Jenkins status regularly?
# ------------------------------------
# 1. Verify service availability before running pipelines
# 2. Detect IP address changes (important for GitHub webhooks)
# 3. Monitor resource utilization (prevent crashes)
# 4. Track costs (AWS Learner Lab budget management)
# 5. Troubleshoot issues (service crashes, network problems)
#
# What is CloudWatch?
# -------------------
# • AWS monitoring and observability service
# • Collects metrics from EC2, Lambda, and other services
# • Default metrics: CPU, network, disk I/O (5-minute intervals)
# • Detailed monitoring: 1-minute intervals (extra cost)
# • Alarms: Trigger actions when metrics cross thresholds
#
# Common Use Cases:
# -----------------
# 1. Before running CI/CD pipeline:
#    → Check if Jenkins is accessible
#    → Verify no IP address changes
#
# 2. After stopping/starting instance:
#    → Get new public IP for GitHub webhook
#    → Verify Jenkins service restarted correctly
#
# 3. Troubleshooting build failures:
#    → Check Jenkins service status
#    → Review resource utilization (CPU/memory)
#
# 4. Cost management:
#    → Track running time
#    → Decide whether to stop instance
#
# Prerequisites:
# --------------
# • Jenkins EC2 instance created (script 40)
# • AWS CLI configured with credentials
# • jq installed (JSON parsing)
# • curl installed (HTTP checks)
#
# Cost Estimate:
# --------------
# • This script: $0 (only API calls, no charges)
# • CloudWatch API calls: Free (within free tier limits)
# • No new resources created
#
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
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

print_explain() {
    echo -e "${YELLOW}  $1${NC}"
}

################################################################################
# Argument Parsing
################################################################################

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

print_header "Jenkins EC2 Status Check"
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo ""

################################################################################
# Load Instance Information
################################################################################

print_info "Loading instance metadata..."
echo ""

INSTANCE_INFO_FILE="$PROJECT_ROOT/.jenkins-ec2-$ENVIRONMENT.info"

if [ ! -f "$INSTANCE_INFO_FILE" ]; then
    print_error "Instance information file not found: $INSTANCE_INFO_FILE"
    echo ""
    print_warning "Jenkins EC2 instance has not been set up yet."
    print_explain "The .jenkins-ec2-*.info file is created by script 41-setup-jenkins-ec2.sh"
    print_explain "This file stores instance metadata: ID, IP, security group, key pair, etc."
    echo ""
    echo "To set up Jenkins on EC2:"
    echo "  ./scripts/jenkins/41-setup-jenkins-ec2.sh --$ENVIRONMENT"
    echo ""
    exit 1
fi

# Source the instance info (loads variables: INSTANCE_ID, PUBLIC_IP, etc.)
source "$INSTANCE_INFO_FILE"

if [ -z "$INSTANCE_ID" ]; then
    print_error "INSTANCE_ID not found in instance info file"
    print_warning "Instance info file may be corrupted"
    exit 1
fi

print_success "Instance metadata loaded"
echo "  Instance ID: $INSTANCE_ID"
echo ""

################################################################################
# Check EC2 Instance Existence and State
################################################################################

print_header "EC2 Instance Status"

print_info "What are we checking?"
print_explain "Querying AWS EC2 API for instance details"
print_explain "This verifies the instance still exists and gets current state"
echo ""

# Explanation of command:
# aws ec2 describe-instances: Get detailed info about EC2 instances
# --instance-ids "$INSTANCE_ID": Filter by specific instance ID
# --query 'Reservations[0].Instances[0]': Extract first instance from results
# 2>/dev/null || echo "null": If instance not found, return "null"
INSTANCE_INFO=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0]' 2>/dev/null || echo "null")

if [ "$INSTANCE_INFO" == "null" ] || [ -z "$INSTANCE_INFO" ]; then
    print_error "Instance $INSTANCE_ID not found in AWS"
    echo ""
    print_warning "Possible reasons:"
    print_explain "• Instance was terminated (permanently deleted)"
    print_explain "• Instance is in a different region"
    print_explain "• AWS credentials don't have EC2 describe permissions"
    echo ""
    echo "To create a new instance:"
    echo "  ./scripts/jenkins/41-setup-jenkins-ec2.sh --$ENVIRONMENT"
    echo ""
    exit 1
fi

# Parse instance details using jq
# Explanation of jq expressions:
# '.State.Name': Current instance state (running, stopped, etc.)
# '.PublicIpAddress // "N/A"': Public IP or "N/A" if not assigned
# '.PrivateIpAddress // "N/A"': Private IP within VPC
# '.InstanceType': Instance type (e.g., t2.small)
# '.Placement.AvailabilityZone': Physical data center location
# '.LaunchTime': ISO 8601 timestamp when instance started
INSTANCE_STATE=$(echo "$INSTANCE_INFO" | jq -r '.State.Name')
CURRENT_PUBLIC_IP=$(echo "$INSTANCE_INFO" | jq -r '.PublicIpAddress // "N/A"')
PRIVATE_IP=$(echo "$INSTANCE_INFO" | jq -r '.PrivateIpAddress // "N/A"')
INSTANCE_TYPE=$(echo "$INSTANCE_INFO" | jq -r '.InstanceType')
AVAILABILITY_ZONE=$(echo "$INSTANCE_INFO" | jq -r '.Placement.AvailabilityZone')
LAUNCH_TIME=$(echo "$INSTANCE_INFO" | jq -r '.LaunchTime')

# Display EC2 instance status with detailed explanations
echo "Instance Details:"
echo "  State: $INSTANCE_STATE"
case "$INSTANCE_STATE" in
    "running")
        print_explain "→ Instance is active and accessible"
        print_explain "→ You are being charged hourly EC2 costs (~\$0.023/hr)"
        ;;
    "stopped")
        print_explain "→ Instance is halted (no EC2 compute charges)"
        print_explain "→ EBS storage still charged (~\$0.10/GB/month)"
        print_explain "→ Public IP will change when restarted"
        ;;
    "pending")
        print_explain "→ Instance is launching (wait 30-60 seconds)"
        ;;
    "stopping")
        print_explain "→ Instance is shutting down (transitional state)"
        ;;
    "terminated")
        print_explain "→ Instance is permanently deleted (cannot be recovered)"
        ;;
esac

echo ""
echo "  Instance Type: $INSTANCE_TYPE"
print_explain "→ t2.small: 1 vCPU, 2GB RAM, moderate network performance"
echo ""

echo "  Public IP: $CURRENT_PUBLIC_IP"
if [ "$CURRENT_PUBLIC_IP" != "N/A" ]; then
    print_explain "→ Internet-accessible IP address (used for Jenkins web UI and SSH)"
    print_explain "→ WARNING: This IP changes every time you stop/start the instance!"
else
    print_explain "→ No public IP (only assigned when instance is 'running')"
fi
echo ""

echo "  Private IP: $PRIVATE_IP"
print_explain "→ Internal VPC IP address (stays constant, not internet-accessible)"
echo ""

echo "  Availability Zone: $AVAILABILITY_ZONE"
print_explain "→ Physical AWS data center location"
echo ""

echo "  Launch Time: $LAUNCH_TIME"
print_explain "→ When instance was last started (used for uptime calculation)"
echo ""

################################################################################
# Check for Public IP Changes
################################################################################

if [ "$CURRENT_PUBLIC_IP" != "$PUBLIC_IP" ] && [ "$CURRENT_PUBLIC_IP" != "N/A" ]; then
    print_header "⚠️  Public IP Address Change Detected"

    print_warning "The public IP has changed since instance was last configured!"
    echo ""
    echo "  Stored IP (in .jenkins-ec2-*.info): $PUBLIC_IP"
    echo "  Current IP (from AWS): $CURRENT_PUBLIC_IP"
    echo ""

    print_info "Why did the IP change?"
    print_explain "AWS reassigns public IPs when EC2 instances are stopped and restarted"
    print_explain "This is default behavior unless using Elastic IP (costs extra)"
    echo ""

    print_warning "Action required:"
    echo ""
    echo "1. Update instance info file with new IP:"
    echo "   ./scripts/jenkins/93-start-jenkins-ec2.sh --$ENVIRONMENT"
    echo ""
    echo "2. Update GitHub webhook URL (if configured):"
    echo "   Old: http://$PUBLIC_IP:8080/github-webhook/"
    echo "   New: http://$CURRENT_PUBLIC_IP:8080/github-webhook/"
    echo "   Visit: https://github.com/liu-chun-wu/AWS_final_project/settings/hooks"
    echo ""
fi

################################################################################
# Check Jenkins Service (if instance is running)
################################################################################

if [ "$INSTANCE_STATE" == "running" ]; then
    print_header "Jenkins Service Status"

    if [ "$CURRENT_PUBLIC_IP" == "N/A" ]; then
        print_error "No public IP assigned to instance"
        print_explain "This is unusual for a 'running' instance. Check AWS console."
    else
        JENKINS_URL="http://$CURRENT_PUBLIC_IP:8080"
        echo "Jenkins URL: $JENKINS_URL"
        echo ""

        print_info "Checking Jenkins web interface accessibility..."
        echo ""

        print_explain "What we're testing:"
        print_explain "• HTTP connectivity to port 8080"
        print_explain "• Security group allows inbound traffic"
        print_explain "• Jenkins service is running"
        echo ""

        # Explanation of curl parameters:
        # -s: Silent mode (no progress bar)
        # -o /dev/null: Discard response body
        # -w "%{http_code}": Write HTTP status code
        # --connect-timeout 5: Fail if connection takes > 5 seconds
        # || echo "000": Return "000" if curl fails (connection refused)
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$JENKINS_URL" 2>/dev/null || echo "000")

        print_info "HTTP Status Code: $HTTP_CODE"
        case "$HTTP_CODE" in
            200)
                print_explain "→ 200 OK: Jenkins is accessible and responding"
                ;;
            403)
                print_explain "→ 403 Forbidden: Jenkins is running but requires authentication (normal!)"
                ;;
            000)
                print_explain "→ Connection refused: Jenkins not responding on port 8080"
                ;;
            502)
                print_explain "→ 502 Bad Gateway: Reverse proxy error (if using one)"
                ;;
            503)
                print_explain "→ 503 Service Unavailable: Jenkins is overloaded or starting up"
                ;;
            504)
                print_explain "→ 504 Gateway Timeout: Request timed out"
                ;;
        esac
        echo ""

        if echo "$HTTP_CODE" | grep -q "200\|403"; then
            print_success "Jenkins web interface is accessible!"
            echo ""

            # Try to get Jenkins version from API
            # Unauthenticated API calls may work for basic info
            print_info "Retrieving Jenkins version..."
            JENKINS_VERSION=$(curl -s --connect-timeout 5 "$JENKINS_URL/api/json" 2>/dev/null | jq -r '.version // "unknown"' || echo "unknown")
            if [ "$JENKINS_VERSION" != "unknown" ]; then
                echo "  Jenkins version: $JENKINS_VERSION"
            else
                echo "  Jenkins version: Unable to retrieve (may require authentication)"
            fi
        else
            print_error "Jenkins web interface is NOT accessible"
            echo ""
            print_warning "Troubleshooting steps:"
            echo ""
            echo "1. Check if Jenkins service is running:"
            echo "   ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$CURRENT_PUBLIC_IP"
            echo "   sudo systemctl status jenkins"
            echo ""
            echo "2. View Jenkins startup logs:"
            echo "   sudo journalctl -u jenkins -n 50"
            echo ""
            echo "3. Check if Jenkins is listening on port 8080:"
            echo "   sudo netstat -tlnp | grep 8080"
            echo ""
            echo "4. Restart Jenkins service:"
            echo "   sudo systemctl restart jenkins"
            echo ""
            echo "5. Verify security group allows port 8080:"
            echo "   aws ec2 describe-security-groups --group-ids <sg-id>"
            echo ""
        fi

        # Check for configured Jenkins jobs
        echo ""
        print_info "Checking for configured Jenkins jobs..."
        echo ""

        # Explanation:
        # /api/json?tree=jobs[name]: Jenkins API to list jobs
        # tree parameter: Only return job names (not full config)
        # jq -r '.jobs[]?.name': Extract name field from each job
        JOBS=$(curl -s --connect-timeout 5 "$JENKINS_URL/api/json?tree=jobs[name]" 2>/dev/null | jq -r '.jobs[]?.name' || echo "")

        if [ -n "$JOBS" ]; then
            print_success "Found configured jobs:"
            echo "$JOBS" | while read -r job; do
                echo "  • $job"
                echo "    URL: $JENKINS_URL/job/$job/"
            done
        else
            print_warning "No jobs configured yet"
            echo ""
            echo "To create CI/CD jobs:"
            echo "  ./scripts/jenkins/42-configure-jenkins-jobs.sh --$ENVIRONMENT"
        fi
    fi

    echo ""

    ############################################################################
    # CloudWatch Metrics
    ############################################################################

    print_header "Resource Utilization (CloudWatch Metrics)"

    print_info "What is CloudWatch?"
    print_explain "AWS monitoring service that collects metrics from EC2 instances"
    print_explain "Default metrics: CPU, network, disk (collected every 5 minutes)"
    print_explain "Metrics available after ~5 minutes of instance running"
    echo ""

    print_info "Checking CPU utilization (last hour average)..."
    echo ""

    # Explanation of command:
    # --namespace AWS/EC2: CloudWatch namespace for EC2 metrics
    # --metric-name CPUUtilization: CPU usage percentage
    # --dimensions: Filter by specific instance ID
    # --start-time: 1 hour ago (Unix timestamp or ISO 8601)
    # --end-time: Current time
    # --period 3600: 1-hour aggregation period (in seconds)
    # --statistics Average: Calculate average CPU over period
    # --query 'Datapoints[0].Average': Extract average value
    # --output text: Plain text output (not JSON)

    # Handle different date command formats (GNU vs BSD/macOS)
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

        # Provide context for CPU usage
        if (( $(echo "$CPU_AVG < 30" | bc -l) )); then
            print_explain "→ Low CPU usage (instance is mostly idle)"
        elif (( $(echo "$CPU_AVG < 70" | bc -l) )); then
            print_explain "→ Moderate CPU usage (normal for Jenkins with builds)"
        else
            print_explain "→ High CPU usage (consider larger instance type if sustained)"
        fi
    else
        echo "  CPU Utilization: Data not available yet"
        print_explain "→ CloudWatch metrics appear after ~5 minutes of instance running"
        print_explain "→ Check again in a few minutes"
    fi

    echo ""

    ############################################################################
    # Cost Information
    ############################################################################

    print_header "Cost Information"

    print_info "EC2 Pricing for t2.small:"
    print_explain "• Hourly rate: \$0.023/hour (when running)"
    print_explain "• Daily cost (24/7): ~\$0.55/day"
    print_explain "• Monthly cost (24/7): ~\$16.56/month"
    print_explain "• When stopped: \$0/hour EC2, but EBS storage still charged"
    echo ""

    # Calculate running time and estimated cost
    if [ "$LAUNCH_TIME" != "null" ]; then
        print_info "Current session costs:"
        echo ""

        # Parse launch time to Unix epoch (seconds since 1970-01-01)
        # Handle different date command formats
        LAUNCH_EPOCH=$(date -d "$LAUNCH_TIME" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo $LAUNCH_TIME | cut -d'.' -f1)" +%s)
        CURRENT_EPOCH=$(date +%s)
        RUNNING_SECONDS=$(( CURRENT_EPOCH - LAUNCH_EPOCH ))
        RUNNING_HOURS=$(( RUNNING_SECONDS / 3600 ))
        RUNNING_MINUTES=$(( (RUNNING_SECONDS % 3600) / 60 ))

        # Calculate estimated cost (t2.small = $0.023/hour)
        RUNNING_COST=$(echo "scale=4; $RUNNING_SECONDS / 3600 * 0.023" | bc)

        echo "  Running time: ${RUNNING_HOURS}h ${RUNNING_MINUTES}m"
        echo "  Estimated EC2 cost: \$$RUNNING_COST"
        echo ""

        print_info "Cost optimization tips:"
        print_explain "• Stop instance when not actively using Jenkins"
        print_explain "• Use script 94-stop-jenkins-ec2.sh to stop safely"
        print_explain "• EBS storage (~20GB) costs ~\$2/month even when stopped"
        print_explain "• Terminate instance when project is complete (deletes all data)"
    fi

    echo ""

################################################################################
# Stopped State Handling
################################################################################

elif [ "$INSTANCE_STATE" == "stopped" ]; then
    print_header "Instance Status: STOPPED"

    print_info "What does 'stopped' mean?"
    print_explain "• EC2 instance is halted (like a powered-off computer)"
    print_explain "• All data on EBS volumes is preserved"
    print_explain "• Public IP is released (new IP assigned on next start)"
    print_explain "• No EC2 compute charges (\$0/hour)"
    print_explain "• EBS storage still charged (~\$0.10/GB/month)"
    echo ""

    print_success "Cost while stopped:"
    echo "  EC2 charges: \$0/hour (no charge when stopped)"
    echo "  EBS charges: ~\$2/month for 20GB volume (storage persists)"
    echo ""

    print_info "To start the instance:"
    echo "  ./scripts/jenkins/93-start-jenkins-ec2.sh --$ENVIRONMENT"
    echo ""

    print_warning "Important: Public IP will change when instance restarts"
    print_explain "You'll need to update GitHub webhook URL with new IP"
    echo ""

################################################################################
# Transitional States Handling
################################################################################

else
    print_header "Instance Status: $INSTANCE_STATE"

    print_warning "The instance is in a transitional state."
    echo ""

    print_info "Transitional states:"
    print_explain "• pending: Instance is launching (wait 30-60 seconds)"
    print_explain "• stopping: Instance is shutting down (wait 10-30 seconds)"
    print_explain "• shutting-down: Instance is terminating (wait 10-30 seconds)"
    echo ""

    print_info "Please wait for the instance to reach 'running' or 'stopped' state."
    echo "  Re-run this script in a minute to check updated status."
    echo ""
fi

################################################################################
# Quick Actions Summary
################################################################################

print_header "Quick Actions"

if [ "$INSTANCE_STATE" == "running" ]; then
    print_success "Instance is running. Available actions:"
    echo ""

    echo "Access Jenkins web UI:"
    echo "  http://$CURRENT_PUBLIC_IP:8080"
    echo ""

    echo "SSH to instance:"
    echo "  ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$CURRENT_PUBLIC_IP"
    echo ""

    echo "View Jenkins logs in real-time:"
    echo "  ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$CURRENT_PUBLIC_IP \\"
    echo "    'sudo journalctl -u jenkins -f'"
    echo ""

    echo "Check Jenkins service status:"
    echo "  ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$CURRENT_PUBLIC_IP \\"
    echo "    'sudo systemctl status jenkins'"
    echo ""

    echo "Restart Jenkins service (if needed):"
    echo "  ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$CURRENT_PUBLIC_IP \\"
    echo "    'sudo systemctl restart jenkins'"
    echo ""

    echo "Stop instance to save costs:"
    echo "  ./scripts/jenkins/94-stop-jenkins-ec2.sh --$ENVIRONMENT"
    echo ""

elif [ "$INSTANCE_STATE" == "stopped" ]; then
    print_warning "Instance is stopped. Available actions:"
    echo ""

    echo "Start instance:"
    echo "  ./scripts/jenkins/93-start-jenkins-ec2.sh --$ENVIRONMENT"
    echo ""
fi

echo "Other useful commands:"
echo "  Smoke-test deployed API endpoints:"
echo "    ./scripts/jenkins/32-cd-verify-deployment.sh --$ENVIRONMENT"
echo ""
echo "  Configure Jenkins CI/CD jobs:"
echo "    ./scripts/jenkins/42-configure-jenkins-jobs.sh --$ENVIRONMENT"
echo ""
echo "  View CloudWatch logs:"
echo "    aws logs tail /aws/lambda/flask-demo-backend-FlaskDemoFunction-* --follow"
echo ""

print_header "Status Check Complete"
