#!/bin/bash
################################################################################
# Script: 94-stop-jenkins-ec2.sh
# Purpose: Stop Jenkins EC2 instance to save costs
# Usage: ./94-stop-jenkins-ec2.sh [--demo|--prod]
#
################################################################################
# What is EC2 Instance Stop Operation?
################################################################################
#
# This script stops a running EC2 instance, transitioning it from 'running'
# to 'stopped' state. This is the primary cost optimization strategy for EC2 -
# when stopped, you pay $0/hour for EC2 compute (only EBS storage charged).
#
# What happens when you stop an EC2 instance?
# --------------------------------------------
# 1. State transition: running → stopping → stopped (10-30 seconds)
# 2. Jenkins service shuts down gracefully
# 3. All processes terminated, RAM contents lost
# 4. EBS volumes remain attached (all data preserved on disk)
# 5. Public IP address released (will get new IP on restart)
# 6. Private IP address preserved (VPC internal IP unchanged)
# 7. EC2 billing stops: $0/hour for stopped instances
# 8. EBS billing continues: ~$0.10/GB/month for storage
#
# Stop vs Terminate - What's the difference?
# -------------------------------------------
# STOP:
# • Temporary shutdown (like powering off a computer)
# • All data on EBS volumes preserved
# • Can restart later with all data intact
# • No EC2 charges while stopped (only EBS storage charged)
# • Public IP changes when restarted
# • Reversible operation
#
# TERMINATE:
# • Permanent deletion (like destroying a computer)
# • All data on EBS volumes deleted (unless configured to persist)
# • Cannot restart - instance is gone forever
# • No charges at all (EC2 and EBS both deleted)
# • Instance ID cannot be reused
# • IRREVERSIBLE operation
#
# Cost savings with stop:
# -----------------------
# • EC2 t2.small: $0.023/hour → $0/hour (save $0.023/hour)
# • Daily savings: ~$0.55/day ($16.56/month)
# • EBS 20GB volume: ~$2/month (continues while stopped)
#
# Example cost scenarios:
# • 24/7 running: $16.56/month EC2 + $2 EBS = $18.56/month
# • 8 hours/day (stop at night): $5.52/month EC2 + $2 EBS = $7.52/month
# • Always stopped: $0/month EC2 + $2 EBS = $2/month
#
# What you'll learn in this script:
# ----------------------------------
# 1. Checking EC2 instance state before stopping
# 2. User confirmation for destructive operations
# 3. Stopping instances with aws ec2 stop-instances
# 4. Waiting for instance to reach 'stopped' state (aws ec2 wait)
# 5. Understanding cost implications (EC2 vs EBS charges)
# 6. Best practices for cost optimization
# 7. Handling edge cases (already stopped, terminated, etc.)
#
# When to stop Jenkins EC2 instance:
# -----------------------------------
# 1. End of work day (if not running overnight builds)
# 2. Weekends (if no CI/CD activity planned)
# 3. AWS Learner Lab session ends (instances auto-stop anyway)
# 4. Budget constraints (stop to avoid charges)
# 5. Switching to another project temporarily
#
# When NOT to stop:
# -----------------
# 1. Active development with frequent Git pushes
# 2. GitHub webhooks configured for automatic builds
# 3. Long-running build jobs in progress (let them complete first)
# 4. Debugging CI/CD issues (keep running for testing)
# 5. Demo/presentation scheduled (keep accessible)
#
# Impact of stopping:
# -------------------
# 1. Jenkins web UI becomes inaccessible (http://<ip>:8080 down)
# 2. GitHub webhooks will fail (can't reach Jenkins)
# 3. Scheduled builds won't run (Jenkins offline)
# 4. Active build jobs terminated (may need to restart)
# 5. SSH access lost (instance not running)
#
# AWS Services Used:
# ------------------
# • EC2: Stop instances, describe instances, wait for state changes
# • (Indirectly): EBS volumes (remain attached while stopped)
#
# Prerequisites:
# --------------
# • Jenkins EC2 instance exists (from script 40)
# • Instance is in 'running' state
# • AWS CLI configured with credentials
# • No critical build jobs running
#
# Cost Estimate:
# --------------
# • This script: $0 (only API calls, no charges)
# • After stop: EC2 charges drop to $0/hour (EBS continues at ~$2/month)
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
    echo "  --demo  Stop Jenkins demo instance"
    echo "  --prod  Stop Jenkins production instance"
    exit 1
fi

AWS_REGION="${AWS_REGION:-us-east-1}"

print_header "Stop Jenkins EC2 Instance"
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
    echo "  ./scripts/aws-ci-cd/40-setup-jenkins-ec2.sh --$ENVIRONMENT"
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
echo ""

################################################################################
# Check Current Instance State
################################################################################

print_header "Checking Instance State"

print_info "What are we checking?"
print_explain "Querying AWS for current instance state"
print_explain "Can only stop instances in 'running' state"
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
    # Already Stopped State
    ############################################################################
    "stopped")
        print_header "Instance is Already Stopped"

        print_success "Instance is already in 'stopped' state"
        echo ""

        print_info "What does this mean?"
        print_explain "• Instance is powered off (not running)"
        print_explain "• No EC2 compute charges (\$0/hour)"
        print_explain "• EBS storage still charged (~\$2/month for 20GB)"
        print_explain "• All data preserved on EBS volumes"
        print_explain "• Can be restarted anytime"
        echo ""

        print_success "Cost status:"
        echo "  EC2 charges: \$0/hour (stopped = no EC2 cost)"
        echo "  EBS charges: ~\$2/month (storage persists)"
        echo "  Total: ~\$2/month"
        echo ""

        print_info "To start the instance:"
        echo "  ./scripts/aws-ci-cd/93-start-jenkins-ec2.sh --$ENVIRONMENT"
        echo ""
        ;;

    ############################################################################
    # Running State - Stop Instance
    ############################################################################
    "running")
        print_header "Stopping Running Instance"

        print_warning "Impact of stopping the instance:"
        echo ""
        echo "  What will happen:"
        print_explain "• Jenkins web UI becomes inaccessible (port 8080 down)"
        print_explain "• GitHub webhooks will fail (can't reach Jenkins)"
        print_explain "• Active build jobs will be terminated"
        print_explain "• SSH access will be lost"
        echo ""

        print_success "Benefits:"
        print_explain "• Save ~\$0.023/hour EC2 costs"
        print_explain "• Save ~\$0.55/day or ~\$16.56/month if kept stopped"
        print_explain "• All data preserved (can restart anytime)"
        echo ""

        print_warning "Important notes:"
        print_explain "• Public IP will change when instance restarts"
        print_explain "• GitHub webhook URL must be updated after restart"
        print_explain "• Jenkins URL will change to new IP"
        echo ""

        # User confirmation for safety
        print_info "Please confirm this operation"
        echo ""
        read -p "Are you sure you want to stop the instance? (yes/no): " CONFIRM

        if [ "$CONFIRM" != "yes" ]; then
            echo ""
            print_warning "Operation cancelled by user"
            echo ""
            echo "Instance remains in 'running' state"
            echo "  Jenkins URL: http://$PUBLIC_IP:8080"
            echo ""
            exit 0
        fi

        echo ""
        print_header "Stopping Instance"

        print_info "What happens during instance stop?"
        print_explain "1. AWS sends shutdown signal to instance"
        print_explain "2. Operating system performs graceful shutdown"
        print_explain "3. Jenkins service stops (build jobs terminated)"
        print_explain "4. All processes terminated, RAM cleared"
        print_explain "5. EBS volumes remain attached (data preserved)"
        print_explain "6. Instance transitions: running → stopping → stopped"
        print_explain "7. Public IP released back to AWS pool"
        print_explain "8. EC2 billing stops"
        print_explain "9. Typical duration: 10-30 seconds"
        echo ""

        print_info "Sending stop command to AWS..."
        echo ""

        # Explanation of command:
        # aws ec2 stop-instances: Stop running EC2 instances
        # --instance-ids: Specify which instance to stop
        # --output text: Plain text output
        # > /dev/null: Discard output (we don't need it)
        aws ec2 stop-instances \
            --region "$AWS_REGION" \
            --instance-ids "$INSTANCE_ID" \
            --output text > /dev/null

        print_success "Stop command sent to AWS"
        echo ""

        print_info "Waiting for instance to reach 'stopped' state..."
        print_explain "This typically takes 10-30 seconds"
        echo ""

        # Explanation of command:
        # aws ec2 wait instance-stopped: Poll until instance is stopped
        # Checks every 15 seconds, max 40 checks (10 minutes total)
        # Returns when State.Name == 'stopped'
        aws ec2 wait instance-stopped \
            --region "$AWS_REGION" \
            --instance-ids "$INSTANCE_ID"

        print_success "Instance stopped successfully!"
        echo ""

        print_header "Cost Savings Summary"

        print_success "EC2 compute charges stopped"
        echo "  Before stop: \$0.023/hour"
        echo "  After stop: \$0.00/hour"
        echo "  Hourly savings: \$0.023/hour"
        echo ""

        echo "  Daily savings: ~\$0.55/day"
        echo "  Monthly savings (if kept stopped): ~\$16.56/month"
        echo ""

        print_info "EBS storage charges continue"
        echo "  EBS volume: 20GB at ~\$0.10/GB/month"
        echo "  EBS cost: ~\$2/month (data persists while stopped)"
        echo ""

        print_success "Total cost while stopped: ~\$2/month (EBS only)"
        echo ""

        print_header "Next Steps"

        echo "When you're ready to use Jenkins again:"
        echo ""
        echo "1. Start the instance:"
        echo "   ./scripts/aws-ci-cd/93-start-jenkins-ec2.sh --$ENVIRONMENT"
        echo ""
        echo "2. Note the new public IP address (will be shown by script 93)"
        echo ""
        echo "3. Update GitHub webhook URL with new IP:"
        echo "   https://github.com/liu-chun-wu/AWS_final_project/settings/hooks"
        echo "   New format: http://<new-ip>:8080/github-webhook/"
        echo ""

        print_warning "Important reminders:"
        print_explain "• Public IP WILL change when instance restarts"
        print_explain "• Bookmark this: Script 93 shows new IP automatically"
        print_explain "• GitHub webhooks won't work until URL updated"
        echo ""
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
        echo "  ./scripts/aws-ci-cd/91-check-jenkins-status.sh --$ENVIRONMENT"
        echo ""

        echo "Re-run this script in 1 minute:"
        echo "  ./scripts/aws-ci-cd/94-stop-jenkins-ec2.sh --$ENVIRONMENT"
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
        echo "  ./scripts/aws-ci-cd/40-setup-jenkins-ec2.sh --$ENVIRONMENT"
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
# Cost Management Best Practices
################################################################################

print_header "Cost Management Best Practices"

print_info "When to stop your Jenkins instance:"
echo ""
echo "  ✓ End of work day (if not running overnight builds)"
print_explain "Save 16 hours/day = ~\$0.37/day = ~\$11/month"
echo ""
echo "  ✓ Weekends (if no CI/CD activity planned)"
print_explain "Save 48 hours/weekend = ~\$1.10/weekend = ~\$4.40/month"
echo ""
echo "  ✓ AWS Learner Lab session ends"
print_explain "Instances auto-stop anyway, but good to stop proactively"
echo ""
echo "  ✓ Budget constraints or hitting cost limits"
print_explain "Stop immediately to avoid unexpected charges"
echo ""
echo "  ✓ Switching to another project temporarily"
print_explain "Keep data but stop charging while inactive"
echo ""

print_info "When to keep your Jenkins instance running:"
echo ""
echo "  ✓ Active development with frequent Git pushes"
print_explain "CI pipeline auto-triggers on each push (webhooks)"
echo ""
echo "  ✓ Debugging CI/CD pipeline issues"
print_explain "Need fast iteration cycles for testing"
echo ""
echo "  ✓ Scheduled builds configured (nightly/weekly)"
print_explain "Jenkins must be running to execute scheduled jobs"
echo ""
echo "  ✓ Demo or presentation scheduled"
print_explain "Keep accessible for live demonstrations"
echo ""

print_header "Cost Comparison Calculator"

echo "Scenario 1: Running 24/7"
echo "  EC2: 720 hours/month × \$0.023/hr = \$16.56/month"
echo "  EBS: 20GB × \$0.10/GB = \$2.00/month"
echo "  Total: \$18.56/month"
echo ""

echo "Scenario 2: Running 8 hours/day (stop nights/weekends)"
echo "  EC2: 240 hours/month × \$0.023/hr = \$5.52/month"
echo "  EBS: 20GB × \$0.10/GB = \$2.00/month"
echo "  Total: \$7.52/month"
echo "  Savings: \$11.04/month vs 24/7"
echo ""

echo "Scenario 3: Running 40 hours/week (weekdays only)"
echo "  EC2: 160 hours/month × \$0.023/hr = \$3.68/month"
echo "  EBS: 20GB × \$0.10/GB = \$2.00/month"
echo "  Total: \$5.68/month"
echo "  Savings: \$12.88/month vs 24/7"
echo ""

echo "Scenario 4: Stopped (only EBS charges)"
echo "  EC2: \$0.00/month (stopped)"
echo "  EBS: 20GB × \$0.10/GB = \$2.00/month"
echo "  Total: \$2.00/month"
echo "  Savings: \$16.56/month vs 24/7"
echo ""

print_header "Useful Commands"

echo "Check instance status:"
echo "  ./scripts/aws-ci-cd/91-check-jenkins-status.sh --$ENVIRONMENT"
echo ""

echo "Start instance (when needed):"
echo "  ./scripts/aws-ci-cd/93-start-jenkins-ec2.sh --$ENVIRONMENT"
echo ""

echo "View all AWS resources:"
echo "  ./scripts/aws-ci-cd/90-check-aws-status.sh"
echo ""

echo "Terminate instance permanently (delete all data):"
echo "  ./scripts/aws-ci-cd/99-cleanup-all.sh"
echo ""

print_header "Stop Operation Complete"
