#!/bin/bash
################################################################################
# Script: 42-configure-jenkins-jobs.sh
# Purpose: Configure Jenkins CI/CD jobs automatically via REST API
# Usage: ./42-configure-jenkins-jobs.sh [--local|--ec2] [--demo|--prod]
#
################################################################################
# What is Jenkins Job Configuration?
################################################################################
#
# This script automates the creation of Jenkins CI/CD pipeline jobs using
# Jenkins REST API. Instead of manually clicking through the Jenkins UI,
# we programmatically create job configurations via HTTP requests.
#
# What is Jenkins?
# ----------------
# • Open-source automation server for CI/CD pipelines
# • Runs build, test, and deployment tasks automatically
# • Triggered by Git commits (via GitHub webhooks)
# • Extensible with 1000+ community plugins
# • Industry standard for DevOps automation (used by Netflix, LinkedIn, etc.)
#
# What is Jenkins REST API?
# -------------------------
# • HTTP-based API for programmatic Jenkins control
# • Allows creating/updating jobs without manual UI clicks
# • Uses XML configuration files for job definitions
# • Requires authentication (username + password/API token)
# • Protected by CSRF tokens (Crumb) for security
#
# Why use Jenkins REST API instead of manual UI setup?
# -----------------------------------------------------
# 1. Infrastructure as Code: Job configs versioned in Git
# 2. Reproducibility: Recreate Jenkins setup quickly (disaster recovery)
# 3. Consistency: Same job configuration across environments (dev/prod)
# 4. Automation: No manual clicking through 20+ UI screens
# 5. Speed: Create 10 jobs in seconds vs 30 minutes manually
#
# What is a Jenkins Pipeline Job?
# --------------------------------
# • Type: Pipeline (workflow-job plugin)
# • Definition: Code-defined build/deploy process (Jenkinsfile)
# • Stages: Sequential steps (checkout → test → build → deploy)
# • Declarative syntax: Easier to read/write than scripted pipelines
# • Version controlled: Jenkinsfile stored in Git repository
#
# Pipeline Job vs Freestyle Job:
# -------------------------------
# • Freestyle: UI-configured, limited flexibility, legacy approach
# • Pipeline: Code-defined, version-controlled, modern standard
# • Use Pipeline for all new projects (industry best practice)
#
# What is CSRF Protection (Jenkins Crumb)?
# -----------------------------------------
# • Cross-Site Request Forgery protection mechanism
# • Prevents malicious websites from triggering Jenkins actions
# • Required for all POST requests to Jenkins API
# • Obtained via: GET /crumbIssuer/api/json
# • Sent as HTTP header: Jenkins-Crumb: <token>
#
# What you'll learn in this script:
# ----------------------------------
# 1. Jenkins REST API authentication (username + password)
# 2. CSRF protection with crumb tokens
# 3. Plugin installation via API
# 4. Job creation/update using XML configuration
# 5. GitHub webhook configuration for automation
# 6. Pipeline job structure (XML format)
# 7. Error handling for Jenkins API calls
#
# AWS Services Used:
# ------------------
# • EC2: Jenkins server (already running from script 40)
# • GitHub: Source code repository (webhook triggers)
# • (Indirectly): ECR, Lambda via Jenkins pipelines
#
# Prerequisites:
# --------------
# • Jenkins EC2 instance running (from 41-setup-jenkins-ec2.sh)
# • Jenkins initial setup wizard completed
# • Admin user created in Jenkins
# • GitHub repository with jenkins-pipeline-setting/Jenkinsfile-CI and Jenkinsfile-CD
# • jq installed (JSON parsing)
# • curl installed (HTTP requests)
#
# Cost Estimate:
# --------------
# • This script itself: $0 (only API calls, no new resources)
# • EC2 instance cost: Handled by script 40 (default t3.medium ~ $0.0416/hr)
# • Total running cost: ~$0.55/day if Jenkins left running 24/7
# • Recommendation: Stop EC2 when not in use (script 94-stop-jenkins-ec2.sh)
#
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "${SCRIPT_DIR}/env-common.sh"

################################################################################
# Helper Functions for Output Formatting
################################################################################

# ANSI color codes for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color

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

usage() {
    cat <<EOF
Usage: $0 [--local|--ec2] [--demo|--prod]

Options:
  --local        Configure Jenkins jobs on the local Dockerized controller.
  --ec2          Configure Jenkins jobs on the EC2 instance provisioned by 41-setup-jenkins-ec2.sh.
  --demo         Use demo environment metadata (default).
  --prod         Use production environment metadata.
  -h, --help     Show this help text.
EOF
}

TARGET=""
ENVIRONMENT="demo"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --local)
            TARGET="local"
            shift
            ;;
        --ec2)
            TARGET="ec2"
            shift
            ;;
        --demo)
            ENVIRONMENT="demo"
            shift
            ;;
        --prod)
            ENVIRONMENT="prod"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [ -z "$TARGET" ]; then
    echo "Error: you must specify --local or --ec2"
    usage
    exit 1
fi

TARGET_DESCRIPTION=$([ "$TARGET" = "ec2" ] && echo "EC2" || echo "local")
TARGET_FLAG="--$TARGET"

GITHUB_REPO="${PIPELINE_GITHUB_REPO:-${GITHUB_REPO:-https://github.com/liu-chun-wu/AWS_final_project.git}}"

print_header "Phase 5: Jenkins Jobs Configuration"
echo "Target Jenkins: $TARGET_DESCRIPTION"
echo "Environment: ${ENVIRONMENT:-default}"
echo "GitHub Repository: $GITHUB_REPO"
echo ""

################################################################################
# STEP 1: Load Jenkins EC2 Instance Information
################################################################################

if [ "$TARGET" = "ec2" ]; then
    print_header "Step 1: Loading Jenkins EC2 Instance Information"

    print_info "What are we doing?"
    print_explain "Loading instance metadata saved by script 41-setup-jenkins-ec2.sh"
    print_explain "This file contains: Instance ID, Public IP, Security Group, etc."
    DEFAULT_INFO_FILE="$PROJECT_ROOT/.jenkins-ec2.info"
    ALT_INFO_FILE="$PROJECT_ROOT/.jenkins-ec2${ENVIRONMENT:+-$ENVIRONMENT}.info"
    if [ -n "$ENVIRONMENT" ]; then
        INSTANCE_INFO_FILE="$ALT_INFO_FILE"
    else
        INSTANCE_INFO_FILE="$DEFAULT_INFO_FILE"
    fi

    # Fallback: if chosen file missing but the other exists, switch with a notice
    if [ ! -f "$INSTANCE_INFO_FILE" ]; then
        if [ "$INSTANCE_INFO_FILE" != "$DEFAULT_INFO_FILE" ] && [ -f "$DEFAULT_INFO_FILE" ]; then
            print_warning "Requested info file not found; falling back to default: $DEFAULT_INFO_FILE"
            INSTANCE_INFO_FILE="$DEFAULT_INFO_FILE"
        elif [ "$INSTANCE_INFO_FILE" != "$ALT_INFO_FILE" ] && [ -f "$ALT_INFO_FILE" ]; then
            print_warning "Default info file not found; using environment-specific file: $ALT_INFO_FILE"
            INSTANCE_INFO_FILE="$ALT_INFO_FILE"
        fi
    fi

    print_explain "File location: $(basename "$INSTANCE_INFO_FILE") (in project root)"
    echo ""

    if [ ! -f "$INSTANCE_INFO_FILE" ]; then
        print_error "Instance information file not found: $INSTANCE_INFO_FILE"
        echo ""
        print_warning "This means Jenkins EC2 instance hasn't been created yet."
        print_warning "Please run script 41 first to provision Jenkins on EC2:"
        echo ""
        echo "  ./scripts/jenkins/41-setup-jenkins-ec2.sh ${ENVIRONMENT:+--$ENVIRONMENT}"
        echo ""
        exit 1
    fi

    # Source the instance info (loads variables like PUBLIC_IP, INSTANCE_ID, etc.)
    source "$INSTANCE_INFO_FILE"

    if [ -z "$PUBLIC_IP" ]; then
        print_error "PUBLIC_IP not found in instance info file"
        print_warning "Instance info file may be corrupted or incomplete"
        exit 1
    fi

    JENKINS_URL="http://$PUBLIC_IP:8080"

    print_success "Instance information loaded successfully"
    echo "   Instance ID: $INSTANCE_ID"
    echo "   Public IP: $PUBLIC_IP"
    echo "   Jenkins URL: $JENKINS_URL"
    echo ""
else
    print_header "Step 1: Preparing Local Jenkins Connection"
    JENKINS_URL="${LOCAL_JENKINS_URL:-http://localhost:8080}"
    print_info "Using local Jenkins at: $JENKINS_URL"
    print_explain "• Make sure Docker Desktop is running."
    print_explain "• Start the controller with ./scripts/jenkins/40-setup-jenkins-local.sh if needed."
    print_explain "• The script will prompt for your Jenkins username/password."
    echo ""
fi

################################################################################
# STEP 2: Check Jenkins Accessibility
################################################################################

print_header "Step 2: Checking Jenkins Accessibility"

print_info "What are we checking?"
print_explain "Verifying Jenkins web interface is responding to HTTP requests"
print_explain "This ensures:"
if [ "$TARGET" = "ec2" ]; then
    print_explain "  • EC2 instance is running"
    print_explain "  • Jenkins service has started (can take 2-3 minutes after EC2 boot)"
    print_explain "  • Security group allows inbound traffic on port 8080"
else
    print_explain "  • Docker container is running"
    print_explain "  • Jenkins finished booting inside the container"
    print_explain "  • Port 8080 is free on localhost"
fi
print_explain "  • No firewall blocking our requests"
echo ""

print_info "HTTP Status Codes we expect:"
print_explain "• 200 OK: Jenkins is accessible and responding"
print_explain "• 403 Forbidden: Jenkins is running but requires authentication (still good!)"
print_explain "• 000: Connection refused (Jenkins not ready yet)"
print_explain "• 502/503/504: Gateway/service errors (wait and retry)"
echo ""

MAX_ATTEMPTS=30
ATTEMPT=0
JENKINS_ACCESSIBLE=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))

    # Explanation of curl parameters:
    # -s: Silent mode (no progress bar)
    # -o /dev/null: Discard response body (we only need status code)
    # -w "%{http_code}": Write HTTP status code to stdout
    # || echo "000": If curl fails (connection refused), return "000"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$JENKINS_URL" || echo "000")

    # Accept both 200 (OK) and 403 (Forbidden) as success
    # 403 means Jenkins is running but requires login (perfectly fine!)
    if echo "$HTTP_CODE" | grep -q "200\|403"; then
        print_success "Jenkins is accessible (HTTP $HTTP_CODE)"
        JENKINS_ACCESSIBLE=true
        break
    fi

    print_warning "Waiting for Jenkins... (attempt $ATTEMPT/$MAX_ATTEMPTS) [HTTP $HTTP_CODE]"
    sleep 10
done

if [ "$JENKINS_ACCESSIBLE" = false ]; then
    print_error "Jenkins is not accessible at $JENKINS_URL after 5 minutes"
    echo ""
    print_warning "Troubleshooting steps:"
    echo ""
    if [ "$TARGET" = "ec2" ]; then
        echo "1. Verify EC2 instance is running:"
        echo "   aws ec2 describe-instances --instance-ids $INSTANCE_ID \\"
        echo "     --query 'Reservations[0].Instances[0].State.Name'"
        echo ""
        echo "2. Check Jenkins service status via SSH:"
        echo "   ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$PUBLIC_IP \\"
        echo "     'sudo systemctl status jenkins'"
        echo ""
        echo "3. View Jenkins startup logs:"
        echo "   ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$PUBLIC_IP \\"
        echo "     'sudo journalctl -u jenkins -n 50'"
        echo ""
        echo "4. Verify security group allows port 8080:"
        echo "   aws ec2 describe-security-groups --group-ids $SECURITY_GROUP_ID \\"
        echo "     --query 'SecurityGroups[0].IpPermissions'"
        echo ""
    else
        echo "1. Ensure the Docker container is running:"
        echo "   docker ps | grep jenkins-local"
        echo ""
        echo "2. View container logs:"
        echo "   docker logs -f jenkins-local"
        echo ""
        echo "3. Restart the local Jenkins container:"
        echo "   docker restart jenkins-local"
        echo ""
    fi
    exit 1
fi

echo ""

################################################################################
# STEP 3: Get Jenkins Credentials and CSRF Token
################################################################################

print_header "Step 3: Setting Up Jenkins Authentication"

print_info "What is Jenkins authentication?"
print_explain "Jenkins requires username + password for API access"
print_explain "Initial password is auto-generated during first boot"
print_explain "Stored in: /var/lib/jenkins/secrets/initialAdminPassword"
print_explain "After setup wizard, use custom admin credentials"
echo ""

if [ -z "$INITIAL_PASSWORD" ]; then
    print_warning "Initial admin password not found in info file"
    print_warning "This means setup wizard was completed with custom credentials"
    echo ""
    read -p "Username (default: admin): " JENKINS_USER
    JENKINS_USER=${JENKINS_USER:-admin}
    read -sp "Password: " JENKINS_PASSWORD
    echo ""
else
    JENKINS_USER="admin"
    JENKINS_PASSWORD="$INITIAL_PASSWORD"
    print_info "Using initial admin password from instance setup"
fi

echo ""
print_info "Testing Jenkins credentials with crumb token request..."
echo ""

print_info "What is a Jenkins Crumb Token?"
print_explain "CSRF (Cross-Site Request Forgery) protection mechanism"
print_explain "Prevents malicious websites from triggering Jenkins actions"
print_explain "Required for all POST/DELETE requests to Jenkins API"
print_explain "GET request to /crumbIssuer/api/json returns token"
print_explain "Must send token as 'Jenkins-Crumb' HTTP header in POST requests"
echo ""

# Explanation of command:
# curl -s: Silent mode (no progress bar)
# -u "$JENKINS_USER:$JENKINS_PASSWORD": Basic authentication
# "$JENKINS_URL/crumbIssuer/api/json": Jenkins endpoint for crumb token
# 2>/dev/null: Suppress error messages (handled by || echo "")
# | jq -r '.crumb': Extract 'crumb' field from JSON response
# || echo "": If command fails, return empty string
COOKIE_JAR="$(mktemp)"
CRUMB=$(curl -s -c "$COOKIE_JAR" -u "$JENKINS_USER:$JENKINS_PASSWORD" \
    "$JENKINS_URL/crumbIssuer/api/json" 2>/dev/null | jq -r '.crumb' || echo "")

if [ -z "$CRUMB" ] || [ "$CRUMB" == "null" ]; then
    print_error "Could not retrieve Jenkins crumb token"
    echo ""
    print_warning "This typically means one of these issues:"
    echo ""
    echo "1. Jenkins is still in setup wizard mode:"
    print_explain "→ Visit $JENKINS_URL and complete initial setup"
    print_explain "→ Enter initial admin password"
    print_explain "→ Install suggested plugins"
    print_explain "→ Create admin user account"
    echo ""
    echo "2. Credentials are incorrect:"
    print_explain "→ Verify username and password"
    print_explain "→ Try resetting password via Jenkins UI"
    echo ""
    echo "3. Jenkins CSRF protection is disabled (rare):"
    print_explain "→ This script requires CSRF protection enabled (default)"
    echo ""
    print_warning "After fixing the issue above, re-run this script"
    exit 1
fi

print_success "Jenkins credentials validated successfully"
print_success "CSRF protection confirmed (crumb token received)"
echo ""

################################################################################
# STEP 4: Install Required Jenkins Plugins
################################################################################

print_header "Step 4: Installing Required Jenkins Plugins"

print_info "What are Jenkins plugins?"
print_explain "Extensions that add functionality to Jenkins"
print_explain "Over 1800+ community-maintained plugins available"
print_explain "Install via UI or programmatically via REST API"
print_explain "Plugins can be updated independently of Jenkins core"
echo ""

print_info "Plugins we need for CI/CD pipelines:"
REQUIRED_PLUGINS=(
    "git"                    # Git source control integration
    "github"                 # GitHub-specific features (webhooks, status updates)
    "workflow-aggregator"    # Pipeline plugin suite (declarative + scripted)
    "docker-workflow"        # Docker commands in Pipeline (docker.build, docker.push)
    "docker-commons"         # Dependency of docker-workflow (pulls engine/tooling APIs)
    "credentials-binding"    # Bind credentials into environment variables
    "aws-credentials"        # AWS credential type + binding support
    "blueocean"              # Modern Jenkins UI; useful for debugging pipelines
)

echo ""
for plugin in "${REQUIRED_PLUGINS[@]}"; do
    case "$plugin" in
        "git")
            echo "  • git: Clone repositories, checkout branches"
            ;;
        "github")
            echo "  • github: GitHub webhook triggers, commit status updates"
            ;;
        "workflow-aggregator")
            echo "  • workflow-aggregator: Pipeline job support (Jenkinsfile execution)"
            ;;
        "docker-workflow")
            echo "  • docker-workflow: Docker build/push commands in pipelines"
            ;;
        "docker-commons")
            echo "  • docker-commons: Shared Docker APIs required by docker-workflow"
            ;;
        "blueocean")
            echo "  • blueocean: Modern pipeline-centric UI (helps visualize CI/CD)"
            ;;
    esac
done
echo ""

print_info "Checking which plugins are already installed..."
echo ""

# Explanation of command:
# GET /pluginManager/api/json?depth=1: Jenkins API endpoint for installed plugins
# depth=1: Include plugin details (not just names)
# jq -r '.plugins[].shortName': Extract 'shortName' field from each plugin
# 2>/dev/null || echo "": Handle errors gracefully
INSTALLED_PLUGINS=$(curl -s -b "$COOKIE_JAR" -u "$JENKINS_USER:$JENKINS_PASSWORD" \
    "$JENKINS_URL/pluginManager/api/json?depth=1" | \
    jq -r '.plugins[].shortName' 2>/dev/null || echo "")

PLUGINS_TO_INSTALL=()
for plugin in "${REQUIRED_PLUGINS[@]}"; do
    if echo "$INSTALLED_PLUGINS" | grep -q "^${plugin}$"; then
        print_success "$plugin (already installed)"
    else
        print_warning "$plugin (will install)"
        PLUGINS_TO_INSTALL+=("$plugin")
    fi
done

if [ ${#PLUGINS_TO_INSTALL[@]} -gt 0 ]; then
    echo ""
    print_info "Installing ${#PLUGINS_TO_INSTALL[@]} plugin(s)..."
    echo ""

    print_explain "How plugin installation works:"
    print_explain "1. Build XML payload with plugin names"
    print_explain "2. POST to /pluginManager/installNecessaryPlugins"
    print_explain "3. Jenkins downloads plugins + dependencies from update center"
    print_explain "4. Wait 60 seconds for installation to complete"
    print_explain "5. Verify Jenkins API is responsive again"
    echo ""

    # Build XML payload for plugin installation
    # Format: <jenkins><install><plugin><name>git</name></plugin>...</install></jenkins>
    PLUGIN_INSTALL_XML="<jenkins><install>"
    for plugin in "${PLUGINS_TO_INSTALL[@]}"; do
        PLUGIN_INSTALL_XML="${PLUGIN_INSTALL_XML}<plugin><name>${plugin}</name></plugin>"
    done
    PLUGIN_INSTALL_XML="${PLUGIN_INSTALL_XML}</install></jenkins>"

    # Explanation of curl parameters:
    # -X POST: HTTP POST method
    # -H "Content-Type: text/xml": Payload is XML format
    # -H "Jenkins-Crumb: $CRUMB": CSRF protection token
    # -d "$PLUGIN_INSTALL_XML": XML payload with plugin list
    # /pluginManager/installNecessaryPlugins: Jenkins API endpoint
    # > /dev/null: Discard response body (we don't need it)
    curl -s --fail -X POST -b "$COOKIE_JAR" -u "$JENKINS_USER:$JENKINS_PASSWORD" \
        -H "Content-Type: text/xml" \
        -H "Jenkins-Crumb: $CRUMB" \
        -d "$PLUGIN_INSTALL_XML" \
        "$JENKINS_URL/pluginManager/installNecessaryPlugins" > /dev/null

    print_success "Plugin installation initiated"
    print_warning "Waiting for plugins to install (this may take 2-3 minutes)..."
    echo ""

    sleep 60  # Give plugins time to download and install

    # Wait for Jenkins to be ready again (plugins may restart Jenkins internals)
    print_info "Verifying Jenkins is responsive after plugin installation..."
    for i in {1..12}; do
        if curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" "$JENKINS_URL/api/json" > /dev/null 2>&1; then
            print_success "Plugins installed successfully"
            break
        fi
        print_warning "Waiting for Jenkins to restart plugin subsystem... ($i/12)"
        sleep 10
    done
else
    echo ""
    print_success "All required plugins already installed"
fi

echo ""

################################################################################
# STEP 5: Create CI Job Configuration
################################################################################

print_header "Step 5: Creating Jenkins CI Job (flask-ci)"

print_info "What is the CI (Continuous Integration) job?"
print_explain "Automatically runs when code is pushed to the production branch (main)"
print_explain "Pipeline stages:"
print_explain "  1. Checkout: Clone repository from GitHub"
print_explain "  2. Setup: Install Python dependencies"
print_explain "  3. Test: Run pytest suite (pipeline fails if tests fail)"
print_explain "  4. Build: Create Docker image"
print_explain "  5. Push: Upload image to AWS ECR"
echo ""

print_info "Job configuration details:"
print_explain "• Job type: Pipeline (flow-definition)"
print_explain "• Pipeline definition: From SCM (jenkins-pipeline-setting/Jenkinsfile-CI in Git)"
print_explain "• Trigger: GitHub push to production branch (main)"
print_explain "• Parameter: BACKEND_DIR (defaults to production backend)"
echo ""

CI_JOB_NAME="${PIPELINE_CI_JOB:-flask-ci}"

# Create CI job XML configuration
# This is a Pipeline job that reads Jenkinsfile from Git repository
cat > /tmp/flask-ci-config.xml << 'CI_CONFIG_EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.40">
  <description>Flask CI Pipeline - Runs on production branch (main)</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.ChoiceParameterDefinition>
          <name>BACKEND_DIR</name>
          <description>Which backend to build and test?
• production: Production service (default)
• demo: Flask demo for CI/CD validation</description>
          <choices class="java.util.Arrays$ArrayList">
            <a class="string-array">
              <string>production</string>
              <string>demo</string>
            </a>
          </choices>
        </hudson.model.ChoiceParameterDefinition>
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers>
        <com.cloudbees.jenkins.GitHubPushTrigger plugin="github@1.37.0">
          <spec></spec>
        </com.cloudbees.jenkins.GitHubPushTrigger>
      </triggers>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps@2.90">
    <scm class="hudson.plugins.git.GitSCM" plugin="git@4.11.0">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>GITHUB_REPO_PLACEHOLDER</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/Jeffery</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="list"/>
      <extensions/>
    </scm>
    <scriptPath>jenkins-pipeline-setting/Jenkinsfile-CI</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
CI_CONFIG_EOF

print_info "XML configuration explained:"
print_explain "<flow-definition>: Pipeline job type"
print_explain "<hudson.model.ChoiceParameterDefinition>: Dropdown parameter (BACKEND_DIR)"
print_explain "<GitHubPushTrigger>: Auto-trigger on GitHub push events"
print_explain "<CpsScmFlowDefinition>: Pipeline code from SCM (Git)"
print_explain "<scriptPath>jenkins-pipeline-setting/Jenkinsfile-CI: Location of Jenkinsfile in repository"
print_explain "<lightweight>true: Fast checkout (no full clone for Jenkinsfile)"
echo ""

# Replace placeholder with actual GitHub repo URL
sed -i.bak "s|GITHUB_REPO_PLACEHOLDER|$GITHUB_REPO|g" /tmp/flask-ci-config.xml
sed -i.bak "s|Jeffery|${PIPELINE_BRANCH_ALLOWED:-main}|g" /tmp/flask-ci-config.xml
rm -f /tmp/flask-ci-config.xml.bak

# Check if job already exists
# Explanation: GET /job/{name}/api/json returns 200 if job exists, 404 if not
CI_JOB_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -b "$COOKIE_JAR" -u "$JENKINS_USER:$JENKINS_PASSWORD" "$JENKINS_URL/job/$CI_JOB_NAME/api/json")
if [ "$CI_JOB_STATUS" = "200" ]; then
    print_warning "Job '$CI_JOB_NAME' already exists, updating configuration..."
    echo ""
    print_explain "API call: POST /job/$CI_JOB_NAME/config.xml"
    print_explain "Purpose: Update existing job configuration"
    echo ""

    # Update existing job
    # Explanation of curl parameters:
    # -X POST: HTTP POST method
    # -H "Content-Type: application/xml": Payload is XML
    # -H "Jenkins-Crumb: $CRUMB": CSRF protection
    # --data-binary @/tmp/flask-ci-config.xml: Read XML from file (preserve formatting)
    # /job/$CI_JOB_NAME/config.xml: Endpoint to update job config
    curl -s --fail -X POST -b "$COOKIE_JAR" -u "$JENKINS_USER:$JENKINS_PASSWORD" \
        -H "Content-Type: application/xml" \
        -H "Jenkins-Crumb: $CRUMB" \
        --data-binary @/tmp/flask-ci-config.xml \
        "$JENKINS_URL/job/$CI_JOB_NAME/config.xml" > /dev/null
    print_success "CI job updated successfully"
else
    print_info "Creating new job '$CI_JOB_NAME'..."
    echo ""
    print_explain "API call: POST /createItem?name=$CI_JOB_NAME"
    print_explain "Purpose: Create new job from XML configuration"
    echo ""

    # Create new job
    # Explanation:
    # /createItem?name=$CI_JOB_NAME: Endpoint to create job with specified name
    # --data-binary @/tmp/flask-ci-config.xml: XML configuration from file
    curl -s --fail -X POST -b "$COOKIE_JAR" -u "$JENKINS_USER:$JENKINS_PASSWORD" \
        -H "Content-Type: application/xml" \
        -H "Jenkins-Crumb: $CRUMB" \
        --data-binary @/tmp/flask-ci-config.xml \
        "$JENKINS_URL/createItem?name=$CI_JOB_NAME" > /dev/null
    print_success "CI job created successfully"
fi

echo "   Job URL: $JENKINS_URL/job/$CI_JOB_NAME/"
echo ""

################################################################################
# STEP 6: Create CD Job Configuration
################################################################################

print_header "Step 6: Creating Jenkins CD Job (flask-cd)"

print_info "What is the CD (Continuous Deployment) job?"
print_explain "Manual deploy job for production branch (main) when you decide to release"
print_explain "Pipeline stages:"
print_explain "  1. Checkout: Clone repository from GitHub"
print_explain "  2. Validate: Check SAM template syntax"
print_explain "  3. Deploy: Run 'sam deploy' to CloudFormation"
print_explain "  4. Verify: Test deployed API endpoints"
echo ""

print_info "Job configuration details:"
print_explain "• Job type: Pipeline (flow-definition)"
print_explain "• Pipeline definition: From SCM (jenkins-pipeline-setting/Jenkinsfile-CD in Git)"
print_explain "• Trigger: Manual (run when you are ready to deploy from production branch)"
print_explain "• Parameters:"
print_explain "  - BACKEND_DIR: Choose which backend to deploy"
print_explain "  - IMAGE_TAG: Specific ECR image tag (or auto-detect newest immutable tag)"
echo ""

CD_JOB_NAME="${PIPELINE_CD_JOB:-flask-cd}"

# Create CD job XML configuration
cat > /tmp/flask-cd-config.xml << 'CD_CONFIG_EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.40">
  <description>Flask CD Pipeline - Deploys to AWS Lambda from production branch (main)</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.ChoiceParameterDefinition>
          <name>BACKEND_DIR</name>
          <description>Which backend to deploy?
• production: Deploy to prod stack (default)
• demo: Deploy to demo stack</description>
          <choices class="java.util.Arrays$ArrayList">
            <a class="string-array">
              <string>production</string>
              <string>demo</string>
            </a>
          </choices>
        </hudson.model.ChoiceParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>IMAGE_TAG</name>
          <description>ECR image tag to deploy (leave empty to auto-detect newest immutable tag from ECR)</description>
          <defaultValue></defaultValue>
          <trim>true</trim>
        </hudson.model.StringParameterDefinition>
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps@2.90">
    <scm class="hudson.plugins.git.GitSCM" plugin="git@4.11.0">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>GITHUB_REPO_PLACEHOLDER</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/Jeffery</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="list"/>
      <extensions/>
    </scm>
    <scriptPath>jenkins-pipeline-setting/Jenkinsfile-CD</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
CD_CONFIG_EOF

print_info "XML configuration differences from CI job:"
print_explain "• Branch: */${PIPELINE_BRANCH_ALLOWED:-main} - production branch"
print_explain "• scriptPath: jenkins-pipeline-setting/Jenkinsfile-CD (not Jenkinsfile-CI)"
print_explain "• Extra parameter: IMAGE_TAG (allows deploying specific versions)"
echo ""

# Replace placeholder with actual GitHub repo URL
sed -i.bak "s|GITHUB_REPO_PLACEHOLDER|$GITHUB_REPO|g" /tmp/flask-cd-config.xml
sed -i.bak "s|Jeffery|${PIPELINE_BRANCH_ALLOWED:-main}|g" /tmp/flask-cd-config.xml
rm -f /tmp/flask-cd-config.xml.bak

# Check if job already exists
CD_JOB_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -b "$COOKIE_JAR" -u "$JENKINS_USER:$JENKINS_PASSWORD" "$JENKINS_URL/job/$CD_JOB_NAME/api/json")
if [ "$CD_JOB_STATUS" = "200" ]; then
    print_warning "Job '$CD_JOB_NAME' already exists, updating configuration..."
    curl -s --fail -X POST -b "$COOKIE_JAR" -u "$JENKINS_USER:$JENKINS_PASSWORD" \
        -H "Content-Type: application/xml" \
        -H "Jenkins-Crumb: $CRUMB" \
        --data-binary @/tmp/flask-cd-config.xml \
        "$JENKINS_URL/job/$CD_JOB_NAME/config.xml" > /dev/null
    print_success "CD job updated successfully"
else
    print_info "Creating new job '$CD_JOB_NAME'..."
    curl -s --fail -X POST -b "$COOKIE_JAR" -u "$JENKINS_USER:$JENKINS_PASSWORD" \
        -H "Content-Type: application/xml" \
        -H "Jenkins-Crumb: $CRUMB" \
        --data-binary @/tmp/flask-cd-config.xml \
        "$JENKINS_URL/createItem?name=$CD_JOB_NAME" > /dev/null
    print_success "CD job created successfully"
fi

echo "   Job URL: $JENKINS_URL/job/$CD_JOB_NAME/"
echo ""

# Clean up temporary files
rm -f /tmp/flask-ci-config.xml /tmp/flask-cd-config.xml "$COOKIE_JAR"

################################################################################
# STEP 7: GitHub Webhook Configuration Instructions
################################################################################

print_header "Step 7: GitHub Webhook Configuration"

print_info "What is a GitHub Webhook?"
print_explain "HTTP callback triggered by GitHub events (push, pull request, etc.)"
print_explain "Sends POST request to Jenkins when code is pushed"
print_explain "Enables automatic builds without polling (instant triggering)"
print_explain "Requires Jenkins to be publicly accessible on the internet"
echo ""

print_info "How it works:"
print_explain "1. Developer pushes code to GitHub"
print_explain "2. GitHub sends HTTP POST to Jenkins webhook URL"
print_explain "3. Jenkins receives push notification"
print_explain "4. Jenkins checks which branch was pushed (builds only run for production branch)"
print_explain "5. Jenkins triggers CI automatically; deployments use the manual flask-cd job"
echo ""

if [ "$TARGET" = "ec2" ]; then
    print_warning "IMPORTANT: Jenkins must be publicly accessible for webhooks!"
    print_explain "Current Jenkins URL: $JENKINS_URL"
    print_explain "This works if your EC2 has a public IP and the security group allows port 8080"
    echo ""

    echo "To enable automatic builds on Git push, configure GitHub webhook:"
    echo ""
    echo "1. Go to your GitHub repository settings:"
    echo "   https://github.com/liu-chun-wu/AWS_final_project/settings/hooks"
    echo ""
    echo "2. Click 'Add webhook' button"
    echo ""
    echo "3. Configure webhook with these settings:"
    echo ""
    print_info "Payload URL:"
    echo "   $JENKINS_URL/github-webhook/"
    print_explain "Must end with /github-webhook/ (Jenkins GitHub plugin endpoint)"
    echo ""
    print_info "Content type:"
    echo "   application/json"
    print_explain "JSON format for push event data"
    echo ""
    print_info "Secret:"
    echo "   (leave empty or set a secret for added security)"
    print_explain "If set, Jenkins must be configured to validate the secret"
    echo ""
    print_info "SSL verification:"
    echo "   Disable SSL verification (we're using HTTP, not HTTPS)"
    print_explain "For production, use HTTPS with valid SSL certificate"
    echo ""
    print_info "Which events should trigger this webhook?"
    echo "   ☑ Just the push event"
    print_explain "Only trigger on git push (not issues, pull requests, etc.)"
    echo ""
    print_info "Active:"
    echo "   ☑ Checked"
    print_explain "Enable webhook immediately"
    echo ""
    echo "4. Click 'Add webhook' to save"
    echo ""
    echo "5. Test webhook:"
    echo "   a. Make a commit to production branch (main) and push"
echo "   b. Check GitHub webhook page for delivery (green checkmark)"
echo "   c. Verify Jenkins CI job was triggered automatically (flask-cd remains manual)"
    echo ""

    print_warning "EC2 Public IP Changes:"
    print_explain "AWS Learner Lab EC2 instances get new public IPs when stopped/started"
    print_explain "If you stop the EC2 instance (to save costs), the IP will change on restart"
    print_explain "You'll need to update the webhook URL with the new IP address"
    print_explain "Use script 93-start-jenkins-ec2.sh which shows the new webhook URL"
    echo ""
else
    print_warning "Webhooks require Jenkins to be reachable from GitHub."
    print_explain "For local Jenkins you can run jobs manually or expose it via a tunnel (ngrok) before configuring a webhook."
    echo ""
fi

################################################################################
# STEP 8: Summary and Next Steps
################################################################################

print_header "Phase 5: Jenkins Jobs Configuration Complete ✅"

echo "Jenkins URL: $JENKINS_URL"
echo ""

print_success "Jobs Created:"
echo ""
echo "  1. CI Job (production branch):"
echo "     URL: $JENKINS_URL/job/$CI_JOB_NAME/"
echo "     • Triggers: Git push to production branch (main) via GitHub webhook"
echo "     • Pipeline: jenkins-pipeline-setting/Jenkinsfile-CI (version controlled in Git)"
echo "     • Purpose: Test → Build → Push Docker image to ECR (production backend default)"
echo "     • Parameter: BACKEND_DIR (production default; demo available if run manually)"
echo ""
echo "  2. CD Job (production branch, manual trigger):"
echo "     URL: $JENKINS_URL/job/$CD_JOB_NAME/"
echo "     • Trigger: Manual run after validating CI image"
echo "     • Pipeline: jenkins-pipeline-setting/Jenkinsfile-CD (version controlled in Git)"
echo "     • Purpose: Validate → Deploy → Verify Lambda deployment"
echo "     • Parameters: BACKEND_DIR (production default), IMAGE_TAG (optional, auto-detects newest immutable tag)"
echo ""

print_header "Next Steps (Phase 6: Jenkins Pipeline Testing)"

echo "Step 1: Test CI job manually"
echo "----------------------------------------"
echo "a. Visit CI job page:"
echo "   $JENKINS_URL/job/$CI_JOB_NAME/"
echo ""
echo "b. Click 'Build with Parameters' in left sidebar"
echo ""
echo "c. Select parameter:"
echo "   BACKEND_DIR: demo-backend"
echo ""
echo "d. Click 'Build' button"
echo ""
echo "e. Watch console output (click build #1 → Console Output)"
echo ""
echo "f. Verify all stages pass:"
echo "   ✓ Checkout (clone repository)"
echo "   ✓ Setup (install dependencies)"
echo "   ✓ Test (run pytest - 5 tests)"
echo "   ✓ Build (create Docker image)"
echo "   ✓ Push (upload to ECR)"
echo ""
echo "g. Expected result: Build status = SUCCESS (blue ball)"
echo ""
echo ""

echo "Step 2: Test CD job manually (after CI succeeds)"
echo "----------------------------------------"
echo "a. Visit CD job page:"
echo "   $JENKINS_URL/job/$CD_JOB_NAME/"
echo ""
echo "b. Click 'Build with Parameters'"
echo ""
echo "c. Configure parameters:"
echo "   BACKEND_DIR: demo-backend"
echo "   IMAGE_TAG: (leave empty to auto-detect newest immutable tag)"
echo ""
echo "d. Click 'Build' button"
echo ""
echo "e. Watch console output"
echo ""
echo "f. Verify all stages pass:"
echo "   ✓ Checkout"
echo "   ✓ Validate (SAM template)"
echo "   ✓ Deploy (CloudFormation stack creation)"
echo "   ✓ Verify (API endpoint testing)"
echo ""
echo "g. Expected result: Build status = SUCCESS"
echo ""
echo "h. Copy API Gateway URL from console output"
echo ""
echo "i. Test deployed API:"
echo "   curl https://<api-id>.execute-api.us-east-1.amazonaws.com/Prod/health"
echo ""
echo ""

if [ "$TARGET" = "ec2" ]; then
    echo "Step 3: Configure GitHub webhook (for automation)"
    echo "----------------------------------------"
    echo "Follow instructions in Step 7 above to enable automatic triggering"
    echo ""
    echo ""
else
    echo "Step 3: (Optional) Expose local Jenkins for webhooks"
    echo "----------------------------------------"
    echo "Local Jenkins typically runs behind Docker on localhost."
    echo "Use a tunneling tool (e.g., ngrok) if you want GitHub to reach it."
    echo ""
    echo ""
fi

echo "Step 4: Monitor job executions"
echo "----------------------------------------"
echo "• Jenkins Console: $JENKINS_URL"
echo "• CI job builds: $JENKINS_URL/job/$CI_JOB_NAME/"
echo "• CD job builds: $JENKINS_URL/job/$CD_JOB_NAME/"
echo "• CloudWatch Logs:"
echo "    aws logs tail /aws/lambda/${PIPELINE_STACK_DEMO:-flask-demo-backend}-FlaskDemoFunction-* --follow"
echo ""
echo ""

print_info "Troubleshooting Resources:"
echo ""
echo "View job console output:"
echo "  • Click job → Click build number → Console Output"
echo ""
if [ "$TARGET" = "ec2" ]; then
    echo "Check Jenkins EC2 logs via SSH:"
    echo "  ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$PUBLIC_IP 'sudo journalctl -u jenkins -f'"
    echo ""
    echo "Restart Jenkins service:"
    echo "  ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$PUBLIC_IP 'sudo systemctl restart jenkins'"
    echo ""
else
    echo "Check local Jenkins container logs:"
    echo "  docker logs -f jenkins-local"
    echo ""
    echo "Restart local Jenkins container:"
    echo "  docker restart jenkins-local"
    echo ""
fi
echo "View installed plugins:"
echo "  $JENKINS_URL/pluginManager/installed"
echo ""
echo "Jenkins configuration:"
echo "  $JENKINS_URL/configure"
echo ""
echo "Re-run job configuration:"
echo "  ./scripts/jenkins/42-configure-jenkins-jobs.sh $TARGET_FLAG --$ENVIRONMENT"
echo ""

print_header "Configuration Complete!"
print_success "Jenkins CI/CD pipelines are ready for testing"
echo ""
