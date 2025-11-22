#!/bin/bash

################################################################################
# AWS SAM Deployment Script
################################################################################
#
# Purpose: Deploy Flask application to AWS Lambda using SAM
#
# What is SAM?
# - SAM = Serverless Application Model
# - AWS framework for building serverless applications
# - Uses CloudFormation under the hood
# - Simplifies Lambda + API Gateway deployment
#
# This script:
# - Updates SAM configuration with ECR URI
# - Validates SAM template syntax
# - Builds SAM application
# - Deploys to AWS (creates Lambda, API Gateway, IAM roles)
# - Displays deployment outputs (API URLs, function ARN)
#
# What you'll learn:
# - How SAM templates work
# - How CloudFormation manages infrastructure
# - How to deploy Lambda container functions
# - How to configure API Gateway
# - Understanding SAM deployment process
#
################################################################################

set -e  # Exit on any error

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse command-line arguments
BACKEND_SPECIFIED=false
USE_DEMO=false
USE_PROD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --demo)
            BACKEND_SPECIFIED=true
            USE_DEMO=true
            shift
            ;;
        --prod)
            BACKEND_SPECIFIED=true
            USE_PROD=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 --demo|--prod"
            echo ""
            echo "Backend Selection (REQUIRED):"
            echo "  --demo    Deploy demo-backend (Stack: flask-demo-backend)"
            echo "  --prod    Deploy backend (Stack: flask-prod-backend)"
            echo ""
            echo "IMPORTANT: You MUST specify either --demo or --prod."
            echo "This prevents accidental production deployments."
            echo ""
            echo "Examples:"
            echo "  $0 --demo   # Deploy demo backend (safe for testing)"
            echo "  $0 --prod   # Deploy production backend (careful!)"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            echo ""
            echo "Usage: $0 --demo|--prod"
            echo "Use --help for more information"
            exit 1
            ;;
    esac
done

# Validate that exactly one backend was specified
if [ "$BACKEND_SPECIFIED" = false ]; then
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ERROR: Backend not specified                                  ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}You must specify which backend to deploy:${NC}"
    echo ""
    echo "  $0 --demo   # Deploy demo backend (flask-demo-backend)"
    echo "  $0 --prod   # Deploy production backend (flask-prod-backend)"
    echo ""
    echo "Use --help for more information"
    exit 1
fi

if [ "$USE_DEMO" = true ] && [ "$USE_PROD" = true ]; then
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ERROR: Conflicting flags                                      ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}You cannot specify both --demo and --prod${NC}"
    echo ""
    echo "Choose exactly one:"
    echo "  $0 --demo   # Deploy demo backend"
    echo "  $0 --prod   # Deploy production backend"
    exit 1
fi

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SAM_DIR="${PROJECT_ROOT}/aws"
AWS_REGION="us-east-1"

# Set stack name and SAM config based on flag
if [ "$USE_DEMO" = true ]; then
    STACK_NAME="flask-demo-backend"
    SAM_CONFIG="samconfig-demo.toml"
    BACKEND_NAME="demo-backend"
elif [ "$USE_PROD" = true ]; then
    STACK_NAME="flask-prod-backend"
    SAM_CONFIG="samconfig-prod.toml"
    BACKEND_NAME="backend"
else
    # This should never happen due to validation above
    echo "FATAL ERROR: Invalid backend state"
    exit 1
fi

################################################################################
# Helper Functions
################################################################################

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
    echo -e "${CYAN}  $ $1${NC}"
}

print_explain() {
    echo -e "${YELLOW}  ℹ $1${NC}"
}

################################################################################
# Step 1: Get ECR Repository URI
################################################################################

get_ecr_uri() {
    print_header "Step 1: Getting ECR Repository Information"

    print_info "SAM needs to know which Docker image to deploy"
    echo ""

    # Try to load from .env file
    if [ -f "${PROJECT_ROOT}/.env" ]; then
        source "${PROJECT_ROOT}/.env"

        if [ -n "$ECR_URI" ]; then
            print_success "Loaded ECR_URI from .env: ${ECR_URI}"
            REPOSITORY_URI=$ECR_URI
            echo ""
            return
        fi
    fi

    # If not in .env, query AWS
    print_info "Querying AWS for ECR repository URI..."

    REPOSITORY_URI=$(aws ecr describe-repositories \
        --repository-names aws-lab-flask-demo \
        --region ${AWS_REGION} \
        --query 'repositories[0].repositoryUri' \
        --output text 2>/dev/null)

    if [ -z "$REPOSITORY_URI" ] || [ "$REPOSITORY_URI" = "None" ]; then
        print_error "ECR repository not found"
        print_info "You need to push an image to ECR first"
        print_info "Run: ./scripts/aws/03-build-and-push.sh"
        exit 1
    fi

    print_success "ECR Repository URI: ${REPOSITORY_URI}"
    echo ""
}

################################################################################
# Step 2: Verify Image Exists in ECR
################################################################################

verify_image_exists() {
    print_header "Step 2: Verifying Docker Image in ECR"

    print_info "Checking if Docker image exists in ECR..."
    echo ""

    print_info "Command to check for images:"
    print_command "aws ecr describe-images \\"
    print_command "  --repository-name aws-lab-flask-demo \\"
    print_command "  --region ${AWS_REGION}"
    echo ""

    IMAGE_COUNT=$(aws ecr describe-images \
        --repository-name aws-lab-flask-demo \
        --region ${AWS_REGION} \
        --query 'length(imageDetails)' \
        --output text 2>/dev/null || echo "0")

    if [ "$IMAGE_COUNT" -eq 0 ]; then
        print_error "No images found in ECR"
        print_info "You need to push an image first"
        print_info "Run: ./scripts/aws/03-build-and-push.sh"
        exit 1
    fi

    print_success "Found ${IMAGE_COUNT} image(s) in ECR"

    # Get latest image info
    print_info "Latest image:"
    aws ecr describe-images \
        --repository-name aws-lab-flask-demo \
        --region ${AWS_REGION} \
        --query 'reverse(sort_by(imageDetails, &imagePushedAt))[0]' \
        --output table

    echo ""
}

################################################################################
# Step 3: Update SAM Configuration
################################################################################

update_sam_config() {
    print_header "Step 3: Updating SAM Configuration"

    print_info "SAM needs to know which ECR repository to use for the Lambda function"
    echo ""

    print_info "Configuration file: aws/${SAM_CONFIG}"
    print_info "Backend: ${BACKEND_NAME}"
    print_info "This file stores deployment settings so you don't have to type them every time"
    echo ""

    # Read current SAM config file
    SAMCONFIG_FILE="${SAM_DIR}/${SAM_CONFIG}"

    if [ ! -f "$SAMCONFIG_FILE" ]; then
        print_error "${SAM_CONFIG} not found at ${SAMCONFIG_FILE}"
        exit 1
    fi

    # Check if image_repositories line is commented
    if grep -q "^# image_repositories" "$SAMCONFIG_FILE"; then
        print_info "Uncommenting and updating image_repositories in ${SAM_CONFIG}..."

        # Uncomment and set the correct URI
        sed -i.bak "s|^# image_repositories = .*|image_repositories = [\"FlaskDemoFunction=${REPOSITORY_URI}\"]|" "$SAMCONFIG_FILE"

        print_success "Updated image_repositories in ${SAM_CONFIG}"
    elif grep -q "^image_repositories" "$SAMCONFIG_FILE"; then
        print_info "Updating existing image_repositories in ${SAM_CONFIG}..."

        # Update existing line
        sed -i.bak "s|^image_repositories = .*|image_repositories = [\"FlaskDemoFunction=${REPOSITORY_URI}\"]|" "$SAMCONFIG_FILE"

        print_success "Updated image_repositories in ${SAM_CONFIG}"
    else
        print_info "Adding image_repositories to ${SAM_CONFIG}..."

        # Add to [default.deploy.parameters] section
        sed -i.bak "/\[default.deploy.parameters\]/a\\
image_repositories = [\"FlaskDemoFunction=${REPOSITORY_URI}\"]" "$SAMCONFIG_FILE"

        print_success "Added image_repositories to ${SAM_CONFIG}"
    fi

    print_info "Configuration updated:"
    print_info "  FlaskDemoFunction will use image: ${REPOSITORY_URI}:latest"

    echo ""
}

################################################################################
# Step 4: Validate SAM Template
################################################################################

validate_template() {
    print_header "Step 4: Validating SAM Template"

    print_info "SAM template: aws/template.yaml"
    print_info "This file defines your infrastructure as code"
    echo ""

    print_info "Command to validate template:"
    print_command "sam validate --template ${SAM_DIR}/template.yaml"
    echo ""

    print_explain "What this checks:"
    print_explain "  - YAML syntax is correct"
    print_explain "  - SAM/CloudFormation resource definitions are valid"
    print_explain "  - Required properties are present"
    print_explain "  - References between resources are correct"
    echo ""

    print_info "Validating..."

    cd "${SAM_DIR}"

    if sam validate --template template.yaml; then
        print_success "Template is valid!"
    else
        print_error "Template validation failed"
        print_info "Fix errors in aws/template.yaml and try again"
        exit 1
    fi

    echo ""
}

################################################################################
# Step 5: Build SAM Application
################################################################################

build_sam() {
    print_header "Step 5: Building SAM Application"

    print_info "Command to build SAM application:"
    print_command "sam build --template ${SAM_DIR}/template.yaml"
    echo ""

    print_explain "What 'sam build' does:"
    print_explain "  For container-based Lambda functions (like ours):"
    print_explain "    - Validates template again"
    print_explain "    - Prepares deployment artifacts"
    print_explain "    - Creates .aws-sam/build/ directory"
    print_explain "    - Generates build template"
    print_explain "  Note: Actual Docker image is already in ECR, so no build needed"
    echo ""

    print_info "Building..."

    cd "${SAM_DIR}"

    sam build

    print_success "SAM build complete"

    print_info "Build artifacts created in: ${SAM_DIR}/.aws-sam/build/"

    echo ""
}

################################################################################
# Step 6: Deploy to AWS
################################################################################

deploy_sam() {
    print_header "Step 6: Deploying to AWS"

    print_info "This is the main deployment step!"
    print_info "SAM will create a CloudFormation stack with all your AWS resources"
    echo ""

    print_info "Command to deploy:"
    print_command "sam deploy --config-file ${SAM_CONFIG}"
    print_info "  Stack: ${STACK_NAME}"
    print_info "  Backend: ${BACKEND_NAME}"
    echo ""

    print_explain "What happens during deployment:"
    print_explain "  1. SAM packages your application"
    print_explain "  2. Uploads artifacts to S3 (SAM-managed bucket)"
    print_explain "  3. Creates CloudFormation changeset (preview of changes)"
    print_explain "  4. Executes changeset to create/update resources:"
    print_explain "     - Lambda function (from ECR image)"
    print_explain "     - IAM role (for Lambda execution)"
    print_explain "     - API Gateway (HTTP API)"
    print_explain "     - CloudWatch log group"
    print_explain "  5. Displays stack outputs (API URLs, ARNs, etc.)"
    echo ""

    print_warning "This will create AWS resources that may incur costs"
    print_info "Estimated cost: ~\$0.12/month (mostly ECR storage)"
    echo ""

    read -p "Continue with deployment? (Y/n): " -n 1 -r
    echo ""
    echo ""

    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_warning "Deployment cancelled"
        exit 0
    fi

    print_info "Deploying to AWS..."
    print_info "This may take 2-3 minutes..."
    echo ""

    cd "${SAM_DIR}"

    # Deploy with automatic confirmation using specified config file
    sam deploy --config-file ${SAM_CONFIG} --no-confirm-changeset --no-fail-on-empty-changeset

    if [ $? -eq 0 ]; then
        print_success "Deployment successful!"
    else
        print_error "Deployment failed"
        print_info "Check CloudFormation console for details"
        print_info "Or run: aws cloudformation describe-stack-events --stack-name ${STACK_NAME}"
        exit 1
    fi

    echo ""
}

################################################################################
# Step 7: Get Stack Outputs
################################################################################

get_stack_outputs() {
    print_header "Step 7: Getting Deployment Outputs"

    print_info "CloudFormation stack outputs contain important information:"
    print_info "  - API Gateway URL (to access your app)"
    print_info "  - Lambda function ARN"
    print_info "  - CloudWatch log group"
    echo ""

    print_info "Command to get stack outputs:"
    print_command "aws cloudformation describe-stacks \\"
    print_command "  --stack-name ${STACK_NAME} \\"
    print_command "  --query 'Stacks[0].Outputs'"
    echo ""

    print_info "Retrieving outputs..."
    echo ""

    # Get outputs
    OUTPUTS=$(aws cloudformation describe-stacks \
        --stack-name ${STACK_NAME} \
        --region ${AWS_REGION} \
        --query 'Stacks[0].Outputs' \
        --output json)

    # Extract specific outputs
    API_URL=$(echo "$OUTPUTS" | grep -A 3 '"OutputKey": "FlaskDemoApi"' | grep "OutputValue" | cut -d'"' -f4)
    HEALTH_URL=$(echo "$OUTPUTS" | grep -A 3 '"OutputKey": "HealthEndpoint"' | grep "OutputValue" | cut -d'"' -f4)
    ECHO_URL=$(echo "$OUTPUTS" | grep -A 3 '"OutputKey": "EchoEndpoint"' | grep "OutputValue" | cut -d'"' -f4)
    FUNCTION_ARN=$(echo "$OUTPUTS" | grep -A 3 '"OutputKey": "FlaskDemoFunction"' | grep "OutputValue" | cut -d'"' -f4)
    LOG_GROUP=$(echo "$OUTPUTS" | grep -A 3 '"OutputKey": "FlaskDemoFunctionLogGroup"' | grep "OutputValue" | cut -d'"' -f4)

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              DEPLOYMENT COMPLETE! ✓                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "  ${BLUE}Stack Name:${NC}          ${STACK_NAME}"
    echo -e "  ${BLUE}AWS Region:${NC}          ${AWS_REGION}"
    echo ""
    echo -e "  ${BLUE}API Gateway URL:${NC}     ${API_URL}"
    echo -e "  ${BLUE}Health Endpoint:${NC}     ${HEALTH_URL}"
    echo -e "  ${BLUE}Echo Endpoint:${NC}       ${ECHO_URL}"
    echo ""
    echo -e "  ${BLUE}Lambda Function:${NC}     ${FUNCTION_ARN}"
    echo -e "  ${BLUE}CloudWatch Logs:${NC}     ${LOG_GROUP}"
    echo ""

    # Save outputs to .env
    if [ -f "${PROJECT_ROOT}/.env" ]; then
        echo "" >> "${PROJECT_ROOT}/.env"
        echo "# Deployment Outputs (generated by 04-deploy-sam.sh)" >> "${PROJECT_ROOT}/.env"
        echo "API_URL=${API_URL}" >> "${PROJECT_ROOT}/.env"
        echo "HEALTH_ENDPOINT=${HEALTH_URL}" >> "${PROJECT_ROOT}/.env"
        echo "ECHO_ENDPOINT=${ECHO_URL}" >> "${PROJECT_ROOT}/.env"
        echo "LAMBDA_FUNCTION_ARN=${FUNCTION_ARN}" >> "${PROJECT_ROOT}/.env"
        echo "LOG_GROUP=${LOG_GROUP}" >> "${PROJECT_ROOT}/.env"

        print_info "Outputs saved to .env file"
    fi

    echo ""
}

################################################################################
# Step 8: Quick Health Check
################################################################################

quick_health_check() {
    print_header "Step 8: Quick Health Check"

    print_info "Testing the /health endpoint to verify deployment..."
    echo ""

    if [ -z "$HEALTH_URL" ]; then
        print_warning "Health URL not found, skipping health check"
        return
    fi

    print_info "Command to test endpoint:"
    print_command "curl ${HEALTH_URL}"
    echo ""

    print_info "Calling health endpoint..."
    echo ""

    RESPONSE=$(curl -s -w "\n%{http_code}" "${HEALTH_URL}")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n-1)

    if [ "$HTTP_CODE" = "200" ]; then
        print_success "Health check passed! (HTTP ${HTTP_CODE})"
        echo ""
        print_info "Response:"
        echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    else
        print_warning "Unexpected HTTP code: ${HTTP_CODE}"
        print_info "Response: ${BODY}"
        print_info "The Lambda function may need a moment to warm up"
        print_info "Try running: ./scripts/aws/05-verify-deployment.sh"
    fi

    echo ""
}

################################################################################
# Step 9: Display Next Steps
################################################################################

display_next_steps() {
    print_header "Next Steps"

    print_info "Your Flask application is now deployed to AWS Lambda!"
    echo ""

    print_info "To thoroughly test the deployment:"
    print_command "./scripts/aws/05-verify-deployment.sh"
    print_info "  - Tests both /health and /echo endpoints"
    print_info "  - Checks CloudWatch logs"
    print_info "  - Validates all success criteria"
    echo ""

    print_info "To monitor CloudWatch logs in real-time:"
    print_command "aws logs tail ${LOG_GROUP} --follow"
    echo ""

    print_info "To check deployment status anytime:"
    print_command "./scripts/aws/check-aws-status.sh"
    echo ""

    print_info "To test endpoints manually:"
    echo -e "  ${CYAN}# Test health endpoint${NC}"
    echo -e "  ${BLUE}curl ${HEALTH_URL}${NC}"
    echo ""
    echo -e "  ${CYAN}# Test echo endpoint${NC}"
    echo -e "  ${BLUE}curl -X POST ${ECHO_URL} \\${NC}"
    echo -e "  ${BLUE}  -H 'Content-Type: application/json' \\${NC}"
    echo -e "  ${BLUE}  -d '{\"message\": \"Hello from AWS Lambda!\"}'${NC}"
    echo ""

    print_info "To update the deployment (after code changes):"
    print_info "  1. Run: ./scripts/aws/03-build-and-push.sh  # Push new image to ECR"
    print_info "  2. Run: ./scripts/aws/04-deploy-sam.sh      # Update Lambda with new image"
    echo ""

    print_info "To view in AWS Console:"
    print_info "  - Lambda: https://console.aws.amazon.com/lambda/home?region=${AWS_REGION}#/functions"
    print_info "  - API Gateway: https://console.aws.amazon.com/apigateway/home?region=${AWS_REGION}"
    print_info "  - CloudWatch: https://console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#logsV2:log-groups"
    echo ""

    print_info "To clean up all resources:"
    print_command "./scripts/aws/99-cleanup-all.sh"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              AWS SAM DEPLOYMENT                                ║${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}║  Deploys Flask app to Lambda + API Gateway + CloudWatch       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Backend: ${BACKEND_NAME}${NC}"
    echo -e "${YELLOW}Stack: ${STACK_NAME}${NC}"
    echo -e "${YELLOW}Config: ${SAM_CONFIG}${NC}"
    echo ""

    get_ecr_uri
    verify_image_exists
    update_sam_config
    validate_template
    build_sam
    deploy_sam
    get_stack_outputs
    quick_health_check
    display_next_steps

    print_success "SAM deployment complete!"
    echo ""
}

# Run main function
main "$@"
