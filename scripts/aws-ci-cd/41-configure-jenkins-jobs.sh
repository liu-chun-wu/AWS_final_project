#!/bin/bash
# Script: 41-configure-jenkins-jobs.sh
# Purpose: Configure Jenkins CI/CD jobs automatically
# Usage: ./41-configure-jenkins-jobs.sh [--demo|--prod]

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
    echo "  --demo  Configure Jenkins for demo environment"
    echo "  --prod  Configure Jenkins for production environment"
    exit 1
fi

GITHUB_REPO="${GITHUB_REPO:-https://github.com/liu-chun-wu/AWS_final_project.git}"

echo "============================================"
echo "Phase 5: Jenkins Jobs Configuration"
echo "============================================"
echo "Environment: $ENVIRONMENT"
echo "GitHub Repository: $GITHUB_REPO"
echo ""

# Step 1: Load instance information
echo "Step 1: Loading Jenkins EC2 instance information..."
echo ""

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

if [ -z "$PUBLIC_IP" ]; then
    echo "❌ PUBLIC_IP not found in instance info file"
    exit 1
fi

JENKINS_URL="http://$PUBLIC_IP:8080"

echo "✅ Instance information loaded"
echo "   Instance ID: $INSTANCE_ID"
echo "   Jenkins URL: $JENKINS_URL"
echo ""

# Step 2: Check Jenkins accessibility
echo "Step 2: Checking Jenkins accessibility..."
echo ""

MAX_ATTEMPTS=30
ATTEMPT=0
JENKINS_ACCESSIBLE=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$JENKINS_URL" || echo "000")

    if echo "$HTTP_CODE" | grep -q "200\|403"; then
        echo "✅ Jenkins is accessible"
        JENKINS_ACCESSIBLE=true
        break
    fi

    echo "   Waiting for Jenkins... (attempt $ATTEMPT/$MAX_ATTEMPTS) [HTTP $HTTP_CODE]"
    sleep 10
done

if [ "$JENKINS_ACCESSIBLE" = false ]; then
    echo "❌ Jenkins is not accessible at $JENKINS_URL"
    echo ""
    echo "Please check:"
    echo "1. Is the EC2 instance running?"
    echo "   aws ec2 describe-instances --instance-ids $INSTANCE_ID"
    echo ""
    echo "2. Is Jenkins service running?"
    echo "   ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@$PUBLIC_IP 'sudo systemctl status jenkins'"
    echo ""
    echo "3. Check security group allows port 8080"
    echo "   aws ec2 describe-security-groups --group-ids $SECURITY_GROUP_ID"
    exit 1
fi

echo ""

# Step 3: Get Jenkins credentials
echo "Step 3: Setting up Jenkins credentials..."
echo ""

if [ -z "$INITIAL_PASSWORD" ]; then
    echo "Initial admin password not found in info file."
    echo "Please enter Jenkins admin credentials:"
    echo ""
    read -p "Username (default: admin): " JENKINS_USER
    JENKINS_USER=${JENKINS_USER:-admin}
    read -sp "Password: " JENKINS_PASSWORD
    echo ""
else
    JENKINS_USER="admin"
    JENKINS_PASSWORD="$INITIAL_PASSWORD"
    echo "Using initial admin password from instance setup"
fi

# Test credentials
echo "Testing Jenkins credentials..."
CRUMB=$(curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" \
    "$JENKINS_URL/crumbIssuer/api/json" 2>/dev/null | jq -r '.crumb' || echo "")

if [ -z "$CRUMB" ] || [ "$CRUMB" == "null" ]; then
    echo "⚠️  Could not retrieve Jenkins crumb token"
    echo "   This may mean:"
    echo "   - Jenkins is still in setup wizard mode (need to complete initial setup first)"
    echo "   - Credentials are incorrect"
    echo "   - Jenkins CSRF protection is disabled"
    echo ""
    echo "Please complete the Jenkins initial setup wizard first:"
    echo "1. Visit: $JENKINS_URL"
    echo "2. Enter initial admin password"
    echo "3. Install suggested plugins"
    echo "4. Create admin user"
    echo "5. Re-run this script"
    exit 1
fi

echo "✅ Jenkins credentials validated"
echo ""

# Step 4: Install required plugins
echo "Step 4: Installing required Jenkins plugins..."
echo ""

REQUIRED_PLUGINS=(
    "git"
    "github"
    "workflow-aggregator"  # Pipeline plugin suite
    "docker-workflow"
)

echo "Required plugins:"
for plugin in "${REQUIRED_PLUGINS[@]}"; do
    echo "  - $plugin"
done
echo ""

# Check which plugins are already installed
echo "Checking installed plugins..."
INSTALLED_PLUGINS=$(curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" \
    "$JENKINS_URL/pluginManager/api/json?depth=1" | \
    jq -r '.plugins[].shortName' 2>/dev/null || echo "")

PLUGINS_TO_INSTALL=()
for plugin in "${REQUIRED_PLUGINS[@]}"; do
    if echo "$INSTALLED_PLUGINS" | grep -q "^${plugin}$"; then
        echo "  ✓ $plugin (already installed)"
    else
        echo "  → $plugin (will install)"
        PLUGINS_TO_INSTALL+=("$plugin")
    fi
done

if [ ${#PLUGINS_TO_INSTALL[@]} -gt 0 ]; then
    echo ""
    echo "Installing ${#PLUGINS_TO_INSTALL[@]} plugin(s)..."

    # Install plugins
    PLUGIN_INSTALL_XML="<jenkins><install>"
    for plugin in "${PLUGINS_TO_INSTALL[@]}"; do
        PLUGIN_INSTALL_XML="${PLUGIN_INSTALL_XML}<plugin><name>${plugin}</name></plugin>"
    done
    PLUGIN_INSTALL_XML="${PLUGIN_INSTALL_XML}</install></jenkins>"

    curl -s -X POST -u "$JENKINS_USER:$JENKINS_PASSWORD" \
        -H "Content-Type: text/xml" \
        -H "Jenkins-Crumb: $CRUMB" \
        -d "$PLUGIN_INSTALL_XML" \
        "$JENKINS_URL/pluginManager/installNecessaryPlugins" > /dev/null

    echo "✅ Plugin installation initiated"
    echo "   Waiting for plugins to install (this may take 2-3 minutes)..."

    sleep 60  # Give plugins time to install

    # Wait for Jenkins to be ready again
    for i in {1..12}; do
        if curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" "$JENKINS_URL/api/json" > /dev/null 2>&1; then
            echo "✅ Plugins installed successfully"
            break
        fi
        echo "   Waiting... ($i/12)"
        sleep 10
    done
else
    echo ""
    echo "✅ All required plugins already installed"
fi

echo ""

# Step 5: Create CI job configuration
echo "Step 5: Creating Jenkins CI job (flask-ci)..."
echo ""

CI_JOB_NAME="flask-ci"

# Create CI job XML configuration
cat > /tmp/flask-ci-config.xml << 'CI_CONFIG_EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.40">
  <description>Flask CI Pipeline - Runs on Jeffery branch for development testing</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.ChoiceParameterDefinition>
          <name>BACKEND_DIR</name>
          <description>Which backend to build and test?
• demo-backend: Flask demo for CI/CD validation
• backend: Production service</description>
          <choices class="java.util.Arrays$ArrayList">
            <a class="string-array">
              <string>demo-backend</string>
              <string>backend</string>
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
    <scriptPath>ci/Jenkinsfile-CI</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
CI_CONFIG_EOF

# Replace placeholder with actual GitHub repo
sed -i.bak "s|GITHUB_REPO_PLACEHOLDER|$GITHUB_REPO|g" /tmp/flask-ci-config.xml
rm -f /tmp/flask-ci-config.xml.bak

# Create or update the job
if curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" "$JENKINS_URL/job/$CI_JOB_NAME/api/json" > /dev/null 2>&1; then
    echo "Job '$CI_JOB_NAME' already exists, updating configuration..."
    curl -s -X POST -u "$JENKINS_USER:$JENKINS_PASSWORD" \
        -H "Content-Type: application/xml" \
        -H "Jenkins-Crumb: $CRUMB" \
        --data-binary @/tmp/flask-ci-config.xml \
        "$JENKINS_URL/job/$CI_JOB_NAME/config.xml" > /dev/null
    echo "✅ CI job updated"
else
    echo "Creating new job '$CI_JOB_NAME'..."
    curl -s -X POST -u "$JENKINS_USER:$JENKINS_PASSWORD" \
        -H "Content-Type: application/xml" \
        -H "Jenkins-Crumb: $CRUMB" \
        --data-binary @/tmp/flask-ci-config.xml \
        "$JENKINS_URL/createItem?name=$CI_JOB_NAME" > /dev/null
    echo "✅ CI job created"
fi

echo "   Job URL: $JENKINS_URL/job/$CI_JOB_NAME/"
echo ""

# Step 6: Create CD job configuration
echo "Step 6: Creating Jenkins CD job (flask-cd)..."
echo ""

CD_JOB_NAME="flask-cd"

# Create CD job XML configuration
cat > /tmp/flask-cd-config.xml << 'CD_CONFIG_EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.40">
  <description>Flask CD Pipeline - Deploys to AWS Lambda from main branch</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.ChoiceParameterDefinition>
          <name>BACKEND_DIR</name>
          <description>Which backend to deploy?
• demo-backend: Deploy to flask-demo-backend stack
• backend: Deploy to flask-prod-backend stack</description>
          <choices class="java.util.Arrays$ArrayList">
            <a class="string-array">
              <string>demo-backend</string>
              <string>backend</string>
            </a>
          </choices>
        </hudson.model.ChoiceParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>IMAGE_TAG</name>
          <description>ECR image tag to deploy (leave empty to auto-detect latest from ECR)</description>
          <defaultValue></defaultValue>
          <trim>true</trim>
        </hudson.model.StringParameterDefinition>
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
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="list"/>
      <extensions/>
    </scm>
    <scriptPath>ci/Jenkinsfile-CD</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
CD_CONFIG_EOF

# Replace placeholder with actual GitHub repo
sed -i.bak "s|GITHUB_REPO_PLACEHOLDER|$GITHUB_REPO|g" /tmp/flask-cd-config.xml
rm -f /tmp/flask-cd-config.xml.bak

# Create or update the job
if curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" "$JENKINS_URL/job/$CD_JOB_NAME/api/json" > /dev/null 2>&1; then
    echo "Job '$CD_JOB_NAME' already exists, updating configuration..."
    curl -s -X POST -u "$JENKINS_USER:$JENKINS_PASSWORD" \
        -H "Content-Type: application/xml" \
        -H "Jenkins-Crumb: $CRUMB" \
        --data-binary @/tmp/flask-cd-config.xml \
        "$JENKINS_URL/job/$CD_JOB_NAME/config.xml" > /dev/null
    echo "✅ CD job updated"
else
    echo "Creating new job '$CD_JOB_NAME'..."
    curl -s -X POST -u "$JENKINS_USER:$JENKINS_PASSWORD" \
        -H "Content-Type: application/xml" \
        -H "Jenkins-Crumb: $CRUMB" \
        --data-binary @/tmp/flask-cd-config.xml \
        "$JENKINS_URL/createItem?name=$CD_JOB_NAME" > /dev/null
    echo "✅ CD job created"
fi

echo "   Job URL: $JENKINS_URL/job/$CD_JOB_NAME/"
echo ""

# Clean up temporary files
rm -f /tmp/flask-ci-config.xml /tmp/flask-cd-config.xml

# Step 7: Display GitHub webhook configuration
echo "Step 7: GitHub Webhook Configuration"
echo "============================================"
echo ""
echo "To enable automatic builds on Git push, configure GitHub webhook:"
echo ""
echo "1. Go to your GitHub repository:"
echo "   https://github.com/liu-chun-wu/AWS_final_project/settings/hooks"
echo ""
echo "2. Click 'Add webhook'"
echo ""
echo "3. Configure webhook:"
echo "   Payload URL: $JENKINS_URL/github-webhook/"
echo "   Content type: application/json"
echo "   Secret: (leave empty or set a secret)"
echo "   SSL verification: Disable SSL verification (for HTTP)"
echo "   Events: Just the push event"
echo "   Active: ✓ (checked)"
echo ""
echo "4. Click 'Add webhook'"
echo ""
echo "⚠️  IMPORTANT: Jenkins must be publicly accessible for webhooks to work"
echo "   Current Jenkins URL: $JENKINS_URL"
echo ""
echo "   If using AWS Learner Lab, the EC2 IP may change if you stop/start"
echo "   the instance. You'll need to update the webhook URL if that happens."
echo ""
echo "============================================"
echo ""

# Step 8: Display summary
echo "============================================"
echo "Phase 5: Jenkins Jobs Configuration Complete ✅"
echo "============================================"
echo ""
echo "Jenkins URL: $JENKINS_URL"
echo ""
echo "Jobs Created:"
echo "  1. CI Job (Jeffery branch):"
echo "     $JENKINS_URL/job/$CI_JOB_NAME/"
echo "     - Triggers: Git push to Jeffery branch"
echo "     - Pipeline: ci/Jenkinsfile-CI"
echo "     - Purpose: Test and build Docker image"
echo ""
echo "  2. CD Job (main branch):"
echo "     $JENKINS_URL/job/$CD_JOB_NAME/"
echo "     - Triggers: Git push to main branch"
echo "     - Pipeline: ci/Jenkinsfile-CD"
echo "     - Purpose: Deploy to AWS Lambda"
echo ""
echo "Next Steps:"
echo "1. Test CI job manually:"
echo "   a. Visit: $JENKINS_URL/job/$CI_JOB_NAME/"
echo "   b. Click 'Build with Parameters'"
echo "   c. Select BACKEND_DIR: demo-backend"
echo "   d. Click 'Build'"
echo "   e. Verify build succeeds"
echo ""
echo "2. Test CD job manually (after CI succeeds):"
echo "   a. Visit: $JENKINS_URL/job/$CD_JOB_NAME/"
echo "   b. Click 'Build with Parameters'"
echo "   c. Select BACKEND_DIR: demo-backend"
echo "   d. Leave IMAGE_TAG empty (auto-detect)"
echo "   e. Click 'Build'"
echo "   f. Verify deployment succeeds"
echo ""
echo "3. Configure GitHub webhook (optional for automation):"
echo "   - Follow instructions above"
echo ""
echo "4. Monitor job executions:"
echo "   - Jenkins Console: $JENKINS_URL"
echo "   - CloudWatch Logs: aws logs tail /aws/lambda/flask-demo-backend-FlaskDemoFunction-* --follow"
echo ""
echo "Troubleshooting:"
echo "  - View job console output in Jenkins UI"
echo "  - Check EC2 instance logs: ssh ec2-user@$PUBLIC_IP 'sudo journalctl -u jenkins -f'"
echo "  - Restart Jenkins: ssh ec2-user@$PUBLIC_IP 'sudo systemctl restart jenkins'"
echo "============================================"
