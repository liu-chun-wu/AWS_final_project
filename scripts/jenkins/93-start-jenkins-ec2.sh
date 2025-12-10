#!/bin/bash
################################################################################
# Script: 93-start-jenkins-ec2.sh
# Purpose: Start a stopped Jenkins EC2 instance
# Usage: ./93-start-jenkins-ec2.sh [--demo|--prod]
#
################################################################################
# What is EC2 Instance Start Operation?
################################################################################
#
# This script starts a stopped EC2 instance, transitioning it from the
# 'stopped' state to the 'running' state. Think of it like powering on
# a computer that was shut down - all data is preserved, but the instance
# gets a new public IP address.
#
# What happens when you start an EC2 instance?
# ---------------------------------------------
# 1. State transition: stopped → pending → running (30-60 seconds)
# 2. New public IP assigned (old IP is released back to AWS pool)
# 3. Private IP stays the same (VPC internal address unchanged)
# 4. EBS volumes reattach automatically (all data preserved)
# 5. User Data script does NOT re-run (only runs on first launch)
# 6. Jenkins service auto-starts (configured via systemd)
# 7. Billing starts: ~$0.0416/hour for t3.medium (default)
#
# Why does the public IP change?
# -------------------------------
# • AWS uses dynamic public IP allocation by default
# • When instance is stopped, public IP is released back to AWS
# • When instance starts, a new public IP is assigned from AWS pool
# • To keep same IP, use Elastic IP (costs extra: $0.005/hour when not attached)
#
# Impact of IP change:
# --------------------
# 1. GitHub webhooks: Must update webhook URL with new IP
# 2. SSH access: Must use new IP for SSH connections
# 3. Bookmarks: Jenkins URL changes (http://<new-ip>:8080)
# 4. Firewall rules: Update any IP-based access controls
#
# What you'll learn in this script:
# ----------------------------------
# 1. Checking EC2 instance state before starting
# 2. Starting instances with aws ec2 start-instances
# 3. Waiting for instance to reach 'running' state (aws ec2 wait)
# 4. Retrieving new public IP after start
# 5. Updating local configuration files with new IP
# 6. Verifying Jenkins service accessibility
# 7. Handling edge cases (already running, terminated, etc.)
#
# When to use this script:
# ------------------------
# 1. After stopping instance to save costs (script 94)
# 2. After AWS Learner Lab session restart (instances auto-stop)
# 3. Before running CI/CD pipelines (Jenkins must be running)
# 4. When troubleshooting (stop + start can fix some issues)
#
# Cost implications:
# ------------------
# • Stopped instance: $0/hour EC2 (but EBS storage still charged)
# • Running instance: ~$0.023/hour EC2 + EBS storage
# • Starting/stopping frequently: No extra charges (just hourly EC2 rate)
# • Recommendation: Keep stopped when not actively using (save ~$16/month)
#
# AWS Services Used:
# ------------------
# • EC2: Start instances, describe instances, wait for state changes
# • (Indirectly): EBS volumes (attached automatically)
#
# Prerequisites:
# --------------
# • Jenkins EC2 instance exists (from script 40)
# • Instance is in 'stopped' state
# • AWS CLI configured with credentials
#
# Cost Estimate:
# --------------
# • This script: $0 (only API calls, no charges)
# • After start: ~$0.023/hour EC2 cost resumes
#
################################################################################

set -e

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
    echo "  --demo  Start Jenkins demo instance"
    echo "  --prod  Start Jenkins production instance"
    exit 1
fi

AWS_REGION="${PIPELINE_AWS_REGION:-${AWS_REGION:-us-east-1}}"

print_header "Start Jenkins EC2 Instance"
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
    print_warning "This means Jenkins EC2 instance hasn't been created yet"
    echo ""
    echo "To create new instance:"
    echo "  ./scripts/jenkins/41-setup-jenkins-ec2.sh --$ENVIRONMENT"
    echo ""
    exit 1
fi

# Source the instance info (loads INSTANCE_ID, PUBLIC_IP, etc.)
source "$INSTANCE_INFO_FILE"

if [ -z "$INSTANCE_ID" ]; then
    print_error "INSTANCE_ID not found in instance info file"
    exit 1
fi

print_success "Instance metadata loaded"
echo "  Instance ID: $INSTANCE_ID"
echo "  Stored Public IP: $PUBLIC_IP"
echo ""

################################################################################
# Check Current Instance State
################################################################################

print_header "Checking Instance State"

print_info "What are we checking?"
print_explain "Querying AWS for current instance state"
print_explain "Possible states: running, stopped, pending, stopping, terminated"
echo ""

# Explanation of command:
# aws ec2 describe-instances: Get instance details
# --instance-ids: Filter by specific instance ID
# --query 'Reservations[0].Instances[0].State.Name': Extract state name
# --output text: Plain text output (not JSON)
# 2>/dev/null || echo "not-found": Return "not-found" if command fails
INSTANCE_STATE=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text 2>/dev/null || echo "not-found")

if [ "$INSTANCE_STATE" == "not-found" ]; then
    print_error "Instance $INSTANCE_ID not found in AWS"
    echo ""
    print_warning "Possible reasons:"
    print_explain "• Instance was terminated (permanently deleted)"
    print_explain "• Instance is in a different region"
    print_explain "• AWS credentials lack EC2 permissions"
    echo ""
    echo "To create a new instance:"
    echo "  ./scripts/jenkins/41-setup-jenkins-ec2.sh --$ENVIRONMENT"
    echo ""
    exit 1
fi

print_success "Instance found in AWS"
echo "  Current state: $INSTANCE_STATE"
echo ""

################################################################################
# Handle Different Instance States
################################################################################

case "$INSTANCE_STATE" in

    ############################################################################
    # Already Running State
    ############################################################################
    "running")
        print_header "Instance is Already Running"

        print_info "What does this mean?"
        print_explain "Instance is already in 'running' state (powered on)"
        print_explain "No action needed, checking for IP address changes"
        echo ""

        # Get current public IP
        CURRENT_IP=$(aws ec2 describe-instances \
            --region "$AWS_REGION" \
            --instance-ids "$INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)

        print_success "Instance details:"
        echo "  Instance ID: $INSTANCE_ID"
        echo "  Public IP: $CURRENT_IP"
        echo "  Jenkins URL: http://$CURRENT_IP:8080"
        echo ""

        # Check if IP has changed since last stored value
        if [ "$CURRENT_IP" != "$PUBLIC_IP" ]; then
            print_warning "Public IP has changed!"
            echo ""
            echo "  Old IP (stored): $PUBLIC_IP"
            echo "  New IP (current): $CURRENT_IP"
            echo ""

            print_info "Why did the IP change?"
            print_explain "AWS reassigns public IPs when instances stop/start"
            print_explain "Even if instance appears running, IP may have changed"
            echo ""

            print_info "Updating instance info file..."
            # Update PUBLIC_IP in the .jenkins-ec2-*.info file
            # sed -i.bak: Edit in-place with backup
            # s|OLD|NEW|g: Substitute pattern globally
            sed -i.bak "s|PUBLIC_IP=.*|PUBLIC_IP=$CURRENT_IP|g" "$INSTANCE_INFO_FILE"
            rm -f "$INSTANCE_INFO_FILE.bak"

            print_success "Info file updated with new IP"
            echo ""

            print_warning "IMPORTANT: Update GitHub webhook URL"
            echo ""
            echo "1. Go to GitHub repository settings:"
            echo "   https://github.com/liu-chun-wu/AWS_final_project/settings/hooks"
            echo ""
            echo "2. Edit existing webhook"
            echo ""
            echo "3. Update Payload URL:"
            echo "   Old: http://$PUBLIC_IP:8080/github-webhook/"
            echo "   New: http://$CURRENT_IP:8080/github-webhook/"
            echo ""
        else
            print_success "Public IP unchanged (no updates needed)"
        fi
        ;;

    ############################################################################
    # Stopped State - Start Instance
    ############################################################################
    "stopped")
        print_header "Starting Instance"

        print_info "What happens during instance start?"
        print_explain "1. AWS transitions instance: stopped → pending → running"
        print_explain "2. New public IP assigned (old IP released)"
        print_explain "3. EBS volumes reattached automatically"
        print_explain "4. User Data script does NOT re-run"
        print_explain "5. Jenkins service starts automatically (systemd enabled)"
        print_explain "6. Typical duration: 30-60 seconds"
        echo ""

        print_info "Starting instance $INSTANCE_ID..."
        echo ""

        # Explanation of command:
        # aws ec2 start-instances: Start stopped EC2 instances
        # --instance-ids: Specify which instance to start
        # --output text: Plain text output
        # > /dev/null: Discard output (we don't need it)
        aws ec2 start-instances \
            --region "$AWS_REGION" \
            --instance-ids "$INSTANCE_ID" \
            --output text > /dev/null

        print_success "Start command sent to AWS"
        echo ""

        print_info "Waiting for instance to reach 'running' state..."
        print_explain "This typically takes 30-60 seconds"
        echo ""

        # Explanation of command:
        # aws ec2 wait instance-running: Poll until instance is running
        # Checks every 15 seconds, max 40 checks (10 minutes total)
        # Returns when State.Name == 'running'
        aws ec2 wait instance-running \
            --region "$AWS_REGION" \
            --instance-ids "$INSTANCE_ID"

        print_success "Instance is now running!"
        echo ""

        # Get new public IP address
        print_info "Retrieving new public IP address..."
        NEW_PUBLIC_IP=$(aws ec2 describe-instances \
            --region "$AWS_REGION" \
            --instance-ids "$INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)

        echo ""
        print_success "Instance Details:"
        echo "  Instance ID: $INSTANCE_ID"
        echo "  Public IP: $NEW_PUBLIC_IP"
        echo "  Jenkins URL: http://$NEW_PUBLIC_IP:8080"
        echo ""

        # Check if IP has changed (it almost always does after stop/start)
        if [ "$NEW_PUBLIC_IP" != "$PUBLIC_IP" ]; then
            print_warning "Public IP has changed (expected behavior)"
            echo ""
            echo "  Old IP: $PUBLIC_IP"
            echo "  New IP: $NEW_PUBLIC_IP"
            echo ""

            print_info "Why does the IP change?"
            print_explain "AWS releases public IPs when instances are stopped"
            print_explain "A new IP is assigned from AWS pool when instance starts"
            print_explain "To keep same IP, use Elastic IP (costs $0.005/hr when not attached)"
            echo ""

            print_info "Updating instance info file with new IP..."
            sed -i.bak "s|PUBLIC_IP=.*|PUBLIC_IP=$NEW_PUBLIC_IP|g" "$INSTANCE_INFO_FILE"
            rm -f "$INSTANCE_INFO_FILE.bak"

            print_success "Info file updated"
            echo ""

            print_warning "IMPORTANT: GitHub webhook URL has changed!"
            echo ""
            echo "The webhook will not work until you update it in GitHub:"
            echo ""
            echo "1. Go to GitHub repository settings:"
            echo "   https://github.com/liu-chun-wu/AWS_final_project/settings/hooks"
            echo ""
            echo "2. Find the existing webhook (will show 'Last delivery failed')"
            echo ""
            echo "3. Click 'Edit' on the webhook"
            echo ""
            echo "4. Update Payload URL:"
            echo "   Old: http://$PUBLIC_IP:8080/github-webhook/"
            echo "   New: http://$NEW_PUBLIC_IP:8080/github-webhook/"
            echo ""
            echo "5. Click 'Update webhook'"
            echo ""
            echo "6. Test webhook by pushing a commit to Jeffery branch"
            echo ""
        fi

        print_header "Waiting for Jenkins Service"

        print_info "What are we waiting for?"
        print_explain "EC2 instance is running, but Jenkins service needs time to start"
        print_explain "Typical Jenkins startup time: 30-60 seconds after instance runs"
        print_explain "We'll check HTTP connectivity to port 8080"
        echo ""

        print_info "Initial wait (30 seconds)..."
        sleep 30

        echo ""
        print_info "Checking Jenkins accessibility..."
        echo ""

        # Try up to 12 times (2 minutes total)
        MAX_ATTEMPTS=12
        JENKINS_READY=false

        for i in $(seq 1 $MAX_ATTEMPTS); do
            # Check if Jenkins responds on port 8080
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$NEW_PUBLIC_IP:8080" || echo "000")

            if echo "$HTTP_CODE" | grep -q "200\|403"; then
                print_success "Jenkins is accessible (HTTP $HTTP_CODE)"
                JENKINS_READY=true
                break
            fi

            if [ $i -eq $MAX_ATTEMPTS ]; then
                print_warning "Jenkins is taking longer than expected to start"
                echo ""
                print_explain "This can happen if:"
                print_explain "• First start after instance launch (plugin initialization)"
                print_explain "• Large number of jobs configured"
                print_explain "• EC2 instance CPU constraints"
                echo ""
                echo "Give it a few more minutes, then check:"
                echo "  http://$NEW_PUBLIC_IP:8080"
                echo ""
                echo "Or SSH to instance and check logs:"
                echo "  ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$NEW_PUBLIC_IP"
                echo "  sudo journalctl -u jenkins -f"
            else
                echo "  Waiting for Jenkins... (attempt $i/$MAX_ATTEMPTS) [HTTP $HTTP_CODE]"
                sleep 10
            fi
        done

        if [ "$JENKINS_READY" = true ]; then
            echo ""
            print_success "Jenkins service is ready!"
        fi
        ;;

    ############################################################################
    # Transitional States
    ############################################################################
    "pending"|"stopping")
        print_header "Instance in Transitional State"

        print_warning "Instance is currently: $INSTANCE_STATE"
        echo ""

        print_info "Transitional states:"
        print_explain "• pending: Instance is starting (wait 30-60 seconds)"
        print_explain "• stopping: Instance is shutting down (wait 10-30 seconds)"
        echo ""

        print_info "Please wait for the instance to reach a stable state"
        print_explain "Stable states: 'running' or 'stopped'"
        echo ""

        echo "Check current status:"
        echo "  ./scripts/jenkins/91-check-jenkins-status.sh --$ENVIRONMENT"
        echo ""

        echo "Re-run this script in 1 minute:"
        echo "  ./scripts/jenkins/93-start-jenkins-ec2.sh --$ENVIRONMENT"
        echo ""
        exit 0
        ;;

    ############################################################################
    # Terminated State
    ############################################################################
    "terminated")
        print_header "Instance Has Been Terminated"

        print_error "Instance $INSTANCE_ID has been permanently deleted"
        echo ""

        print_info "What does 'terminated' mean?"
        print_explain "• Instance is permanently deleted (cannot be recovered)"
        print_explain "• All EBS volumes deleted (unless configured to persist)"
        print_explain "• All data lost (Jenkins config, jobs, build history)"
        print_explain "• No charges (EC2 and EBS both deleted)"
        echo ""

        print_warning "You must create a new instance from scratch"
        echo ""
        echo "To create a new instance:"
        echo "  ./scripts/jenkins/41-setup-jenkins-ec2.sh --$ENVIRONMENT"
        echo ""
        exit 1
        ;;

    ############################################################################
    # Unknown State
    ############################################################################
    *)
        print_error "Unknown instance state: $INSTANCE_STATE"
        echo ""
        print_warning "This is unexpected. Check AWS console for details."
        exit 1
        ;;
esac

################################################################################
# Summary and Next Steps
################################################################################

print_header "Next Steps"

# Get final current IP (may have been updated)
FINAL_IP=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "Access Jenkins web UI:"
echo "  http://$FINAL_IP:8080"
echo ""

echo "SSH to instance:"
echo "  ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$FINAL_IP"
echo ""

echo "Check Jenkins service status:"
echo "  ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$FINAL_IP \\"
echo "    'sudo systemctl status jenkins'"
echo ""

echo "View Jenkins logs:"
echo "  ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$FINAL_IP \\"
echo "    'sudo journalctl -u jenkins -f'"
echo ""

echo "Check comprehensive status:"
echo "  ./scripts/jenkins/91-check-jenkins-status.sh --$ENVIRONMENT"
echo ""

echo "Configure CI/CD jobs (if not done yet):"
echo "  ./scripts/jenkins/42-configure-jenkins-jobs.sh --$ENVIRONMENT"
echo ""

echo "Stop instance when done (to save costs):"
echo "  ./scripts/jenkins/94-stop-jenkins-ec2.sh --$ENVIRONMENT"
echo ""

print_header "Cost Information"

print_info "EC2 t3.medium pricing:"
print_explain "• Hourly: \$0.023/hour (while running)"
print_explain "• Daily: ~\$0.55/day (if running 24/7)"
print_explain "• Monthly: ~\$16.56/month (if running 24/7)"
echo ""

print_warning "Remember to stop the instance when not in use!"
print_explain "Stopping saves ~\$16/month EC2 costs"
print_explain "EBS storage (~\$2/month) persists when stopped"
echo ""

print_header "Start Operation Complete"
