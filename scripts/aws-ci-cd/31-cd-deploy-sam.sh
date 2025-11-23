#!/bin/bash

################################################################################
# SAM Deployment Script - Deploy Lambda via CloudFormation
################################################################################
#
# Script: 31-cd-deploy-sam.sh
# Purpose: Deploy Flask application to AWS Lambda using SAM
# Usage: ./31-cd-deploy-sam.sh [--demo|--prod] [--image-tag <tag>]
#
# What is CD (Continuous Deployment)?
# - Automated process that deploys tested code to production
# - Follows CI (build/test) in the pipeline
# - Uses Infrastructure as Code (SAM templates)
# - Creates or updates cloud resources automatically
# - Can rollback on failure
#
# This script implements CD pipeline:
# 1. Auto-detect or validate ECR image exists
# 2. Build SAM application (prepare CloudFormation)
# 3. Deploy to AWS (Lambda + API Gateway)
# 4. Verify stack creation succeeded
# 5. Output API Gateway URL for testing
#
# What you'll learn:
# - SAM deployment process and CloudFormation stacks
# - Change sets and safe updates
# - Parameter overrides (IMAGE_TAG)
# - Stack outputs (API Gateway URL)
# - CloudFormation resource creation order
# - Image repository resolution
#
# AWS Services Used:
# - SAM CLI - Deployment orchestration
# - CloudFormation - Infrastructure management
# - Lambda - Serverless compute (from ECR image)
# - API Gateway - HTTP endpoints
# - CloudWatch - Logging
# - ECR - Container image source
#
# Prerequisites:
# - ECR repository with Docker image (20-ci-build-and-push.sh)
# - SAM template validated (30-cd-validate-sam.sh)
# - AWS credentials configured
# - LabRole exists in account
#
# Cost:
# - Lambda: Pay per request (~$0.20 per million requests)
# - API Gateway: Pay per request (~$1 per million requests)
# - CloudWatch Logs: ~$0.50 per GB ingested
# - No charges when idle (serverless!)
#
################################################################################

set -e  # Exit immediately if any command fails

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

################################################################################
# Parse Command-Line Arguments
################################################################################

BACKEND_TYPE=""
IMAGE_TAG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --demo)
            BACKEND_TYPE="demo-backend"
            shift
            ;;
        --prod)
            BACKEND_TYPE="prod-backend"
            shift
            ;;
        --image-tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--demo|--prod] [--image-tag <tag>]"
            echo ""
            echo "Deploy Flask application to AWS Lambda via SAM"
            echo ""
            echo "Options:"
            echo "  --demo        Deploy to demo-backend stack (flask-demo-backend)"
            echo "  --prod        Deploy to prod-backend stack (flask-prod-backend)"
            echo "  --image-tag   ECR image tag to deploy (optional, auto-detects latest)"
            echo ""
            echo "Examples:"
            echo "  $0 --demo                           # Auto-detect latest image from ECR"
            echo "  $0 --demo --image-tag manual-test   # Deploy specific image tag"
            echo "  $0 --prod --image-tag jeffery-456   # Deploy to production with tag"
            echo ""
            echo "What this does:"
            echo "  • Deploys Lambda function from ECR container image"
            echo "  • Creates API Gateway HTTP endpoints"
            echo "  • Sets up CloudWatch logging"
            echo "  • Returns API URL for testing"
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate backend type provided
if [ -z "$BACKEND_TYPE" ]; then
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  ERROR: Backend type required                                  ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Usage: $0 [--demo|--prod] [--image-tag <tag>]"
    echo ""
    echo "Options:"
    echo "  --demo  Deploy to demo-backend stack"
    echo "  --prod  Deploy to prod-backend stack"
    echo ""
    echo "Use --help for more information"
    exit 1
fi

AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
REPO_NAME="aws-lab-flask-demo"

# Set stack name and config based on backend type
if [ "$BACKEND_TYPE" == "demo-backend" ]; then
    SAM_CONFIG="aws/samconfig-demo.toml"
    STACK_NAME="flask-demo-backend"
else
    SAM_CONFIG="aws/samconfig-prod.toml"
    STACK_NAME="flask-prod-backend"
fi

################################################################################
# Helper Functions for Output Formatting
################################################################################

# Color codes
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
    echo -e "${CYAN}  \$ $1${NC}"
}

print_explain() {
    echo -e "${YELLOW}  ℹ $1${NC}"
}

################################################################################
# Introduction
################################################################################

show_introduction() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       PHASE 3b: MANUAL CD TESTING - SAM DEPLOY                 ║${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}║  Deploy Lambda + API Gateway via CloudFormation               ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_header "What is CD (Continuous Deployment)?"

    print_info "CD automates deployment of tested code to cloud infrastructure:"
    print_info "  • Follows CI pipeline (test → build → push)"
    print_info "  • Uses Infrastructure as Code (SAM templates)"
    print_info "  • Creates/updates resources automatically"
    print_info "  • Provides rollback on failures"
    print_info "  • Ensures consistent deployments"
    echo ""

    print_info "CD vs CI:"
    print_info "  • CI = Continuous Integration (build & test code)"
    print_info "  • CD = Continuous Deployment (deploy to cloud)"
    print_info "  • Together = Full automation (code → production)"
    echo ""

    print_header "SAM Deployment Process"

    print_info "How SAM deploys to AWS:"
    print_info "  1. Reads SAM template (aws/template.yaml)"
    print_info "  2. Transforms to CloudFormation template"
    print_info "  3. Packages artifacts (uploads to S3 if needed)"
    print_info "  4. Creates CloudFormation change set (preview changes)"
    print_info "  5. Executes change set (creates/updates resources)"
    print_info "  6. Waits for stack completion"
    print_info "  7. Returns outputs (API Gateway URL, Lambda ARN)"
    echo ""

    print_info "Configuration:"
    echo -e "  ${BLUE}Backend Type:${NC}      $BACKEND_TYPE"
    echo -e "  ${BLUE}Stack Name:${NC}        $STACK_NAME"
    echo -e "  ${BLUE}SAM Config:${NC}        $SAM_CONFIG"
    echo -e "  ${BLUE}AWS Region:${NC}        $AWS_REGION"
    echo -e "  ${BLUE}AWS Account:${NC}       $AWS_ACCOUNT_ID"
    echo ""
}

################################################################################
# Step 0: Auto-detect or Validate Image Tag
################################################################################

detect_image_tag() {
    print_header "Step 0: Detecting ECR Image"

    if [ -z "$IMAGE_TAG" ]; then
        print_info "No --image-tag specified, auto-detecting from ECR..."
        echo ""

        print_info "Query command:"
        print_command "aws ecr describe-images \\"
        print_command "    --repository-name $REPO_NAME \\"
        print_command "    --region $AWS_REGION \\"
        print_command "    --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]'"
        echo ""

        print_explain "Auto-detection logic:"
        print_explain "  • Sorts images by push timestamp (imagePushedAt)"
        print_explain "  • Takes the most recent image ([-1])"
        print_explain "  • Extracts the first tag from that image"
        print_explain "  • This is usually 'latest' or a build-specific tag"
        echo ""

        IMAGE_TAG=$(aws ecr describe-images \
            --repository-name "$REPO_NAME" \
            --region "$AWS_REGION" \
            --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' \
            --output text 2>/dev/null)

        if [ -z "$IMAGE_TAG" ] || [ "$IMAGE_TAG" == "None" ]; then
            print_error "No images found in ECR repository: $REPO_NAME"
            echo ""
            echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
            echo -e "${RED}║  Phase 3a (CI) must be completed first!                ║${NC}"
            echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
            echo ""
            print_info "Run Phase 3a to build and push Docker image:"
            if [ "$BACKEND_TYPE" == "demo-backend" ]; then
                print_command "./scripts/aws-ci-cd/20-ci-build-and-push.sh --demo"
            else
                print_command "./scripts/aws-ci-cd/20-ci-build-and-push.sh --prod"
            fi
            echo ""
            print_info "This will:"
            print_info "  1. Run pytest tests"
            print_info "  2. Build Docker image"
            print_info "  3. Push image to ECR"
            echo ""
            print_info "Then retry this deployment script"
            exit 1
        fi

        print_success "Auto-detected image tag: $IMAGE_TAG"

        # Show when image was pushed
        PUSH_TIME=$(aws ecr describe-images \
            --repository-name "$REPO_NAME" \
            --region "$AWS_REGION" \
            --image-ids imageTag=$IMAGE_TAG \
            --query 'imageDetails[0].imagePushedAt' \
            --output text 2>/dev/null)

        print_info "Pushed at: $PUSH_TIME"
    else
        print_info "Using specified image tag: $IMAGE_TAG"
        echo ""

        # Verify specified tag exists
        print_info "Verifying image exists in ECR..."
        IMAGE_EXISTS=$(aws ecr describe-images \
            --repository-name "$REPO_NAME" \
            --region "$AWS_REGION" \
            --image-ids imageTag=$IMAGE_TAG \
            --query 'imageDetails[0].imageDigest' \
            --output text 2>/dev/null)

        if [ -z "$IMAGE_EXISTS" ]; then
            print_error "Image tag '$IMAGE_TAG' not found in ECR"
            echo ""
            print_info "Available tags:"
            aws ecr describe-images \
                --repository-name "$REPO_NAME" \
                --region "$AWS_REGION" \
                --query 'sort_by(imageDetails,&imagePushedAt)[-5:].{Tag:imageTags[0],Pushed:imagePushedAt}' \
                --output table
            echo ""
            exit 1
        fi

        print_success "Image tag verified in ECR"
    fi

    echo ""
    print_info "Deploying with image tag: ${CYAN}$IMAGE_TAG${NC}"
    echo ""
}

################################################################################
# Step 1: Build SAM Application
################################################################################

build_sam() {
    print_header "Step 1: Building SAM Application"

    cd "$PROJECT_ROOT"

    print_info "SAM build prepares the deployment package"
    echo ""

    print_info "Build command:"
    print_command "sam build --template aws/template.yaml"
    echo ""

    print_explain "What 'sam build' does:"
    print_explain "  • Reads SAM template"
    print_explain "  • For container image functions:"
    print_explain "    → Validates image reference (no local build needed)"
    print_explain "    → Image already in ECR from Phase 3a"
    print_explain "  • For ZIP-based functions (not used here):"
    print_explain "    → Downloads dependencies"
    print_explain "    → Packages code"
    print_explain "  • Creates .aws-sam/build/ directory"
    print_explain "  • Generates CloudFormation template"
    echo ""

    print_info "Building (30-60 seconds)..."
    echo ""

    if sam build --template aws/template.yaml; then
        echo ""
        print_success "SAM build successful"
        echo ""

        print_info "Build artifacts:"
        print_info "  • .aws-sam/build/template.yaml (CloudFormation template)"
        print_info "  • .aws-sam/build.toml (build metadata)"
    else
        echo ""
        print_error "SAM build failed"
        echo ""
        print_info "Common build issues:"
        print_info "  • Template syntax errors (run 30-cd-validate-sam.sh)"
        print_info "  • Invalid ECR image reference"
        print_info "  • Missing required template properties"
        exit 1
    fi

    echo ""
}

################################################################################
# Step 2: Deploy to AWS via SAM
################################################################################

deploy_sam() {
    print_header "Step 2: Deploying to AWS Lambda + API Gateway"

    print_info "SAM deploy creates CloudFormation stack with all resources"
    echo ""

    print_info "Deployment command:"
    print_command "sam deploy \\"
    print_command "    --config-file $SAM_CONFIG \\"
    print_command "    --stack-name $STACK_NAME \\"
    print_command "    --parameter-overrides ImageTag=$IMAGE_TAG \\"
    print_command "    --resolve-image-repos \\"
    print_command "    --no-confirm-changeset \\"
    print_command "    --no-fail-on-empty-changeset \\"
    print_command "    --region $AWS_REGION"
    echo ""

    print_explain "Parameters explained:"
    print_explain "  • --config-file $SAM_CONFIG:"
    print_explain "    → Loads deployment settings from TOML file"
    print_explain "    → Contains capabilities, S3 bucket, etc."
    print_explain ""
    print_explain "  • --stack-name $STACK_NAME:"
    print_explain "    → CloudFormation stack name"
    print_explain "    → Groups related resources together"
    print_explain "    → Different stacks for demo vs prod"
    print_explain ""
    print_explain "  • --parameter-overrides ImageTag=$IMAGE_TAG:"
    print_explain "    → Passes IMAGE_TAG to CloudFormation template"
    print_explain "    → Template uses this to reference ECR image"
    print_explain "    → Allows deploying different image versions"
    print_explain ""
    print_explain "  • --resolve-image-repos:"
    print_explain "    → Auto-creates ECR repos if needed (we already have it)"
    print_explain "    → Resolves image URIs in template"
    print_explain ""
    print_explain "  • --no-confirm-changeset:"
    print_explain "    → Skips manual confirmation (automated deployment)"
    print_explain "    → In production, you might want confirmation"
    print_explain ""
    print_explain "  • --no-fail-on-empty-changeset:"
    print_explain "    → Doesn't fail if no changes detected"
    print_explain "    → Useful for idempotent deployments"
    echo ""

    print_info "What happens during deployment:"
    print_info "  1. SAM uploads template to S3 (if not already there)"
    print_info "  2. CloudFormation creates change set (preview of changes)"
    print_info "  3. Change set executed (creates/updates resources):"
    print_info "     a. Lambda function (pulls ECR image)"
    print_info "     b. API Gateway (HTTP API)"
    print_info "     c. CloudWatch Log Group"
    print_info "     d. IAM role association (LabRole)"
    print_info "  4. CloudFormation waits for all resources: CREATE_COMPLETE"
    print_info "  5. Stack outputs generated (API URL, Lambda ARN)"
    echo ""

    print_warning "This may take 3-5 minutes (CloudFormation resource creation)"
    print_info "Watching deployment progress..."
    echo ""

    if sam deploy \
        --config-file "$SAM_CONFIG" \
        --stack-name "$STACK_NAME" \
        --parameter-overrides ImageTag=$IMAGE_TAG \
        --resolve-image-repos \
        --no-confirm-changeset \
        --no-fail-on-empty-changeset \
        --region "$AWS_REGION"; then

        echo ""
        print_success "SAM deployment successful ✓"
    else
        echo ""
        print_error "SAM deployment failed"
        echo ""
        print_info "Common deployment issues:"
        print_info "  • Insufficient IAM permissions"
        print_info "  • LabRole doesn't exist (Learner Lab required)"
        print_info "  • ECR image doesn't exist"
        print_info "  • Resource limit exceeded"
        print_info "  • Invalid template after transformation"
        echo ""
        print_info "Check CloudFormation console for detailed error"
        print_command "aws cloudformation describe-stack-events \\"
        print_command "    --stack-name $STACK_NAME \\"
        print_command "    --region $AWS_REGION"
        echo ""
        exit 1
    fi

    echo ""
}

################################################################################
# Step 3: Retrieve Stack Outputs
################################################################################

get_stack_outputs() {
    print_header "Step 3: Retrieving Deployment Outputs"

    print_info "CloudFormation stacks can define outputs (useful information)"
    echo ""

    print_info "Query command for API URL:"
    print_command "aws cloudformation describe-stacks \\"
    print_command "    --stack-name $STACK_NAME \\"
    print_command "    --query 'Stacks[0].Outputs[?OutputKey==\`ApiUrl\`].OutputValue'"
    echo ""

    print_explain "Understanding stack outputs:"
    print_explain "  • Defined in SAM template under 'Outputs' section"
    print_explain "  • Useful for inter-stack references"
    print_explain "  • Common outputs: API URLs, ARNs, IDs"
    print_explain "  • Queried with JMESPath filters"
    echo ""

    API_URL=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
        --output text 2>/dev/null)

    LAMBDA_ARN=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`FlaskFunctionArn`].OutputValue' \
        --output text 2>/dev/null)

    if [ -z "$API_URL" ]; then
        print_warning "Could not retrieve API URL from stack outputs"
        print_info "Stack may still be creating, or outputs not defined in template"
    else
        print_success "Stack outputs retrieved"
    fi

    echo ""
}

################################################################################
# Display Summary
################################################################################

display_summary() {
    print_header "Deployment Complete ✅"

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       LAMBDA + API GATEWAY DEPLOYED SUCCESSFULLY! ✓           ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_info "Deployment summary:"
    echo ""
    echo -e "  ${BLUE}Stack Name:${NC}        $STACK_NAME"
    echo -e "  ${BLUE}Image Tag:${NC}         $IMAGE_TAG"
    echo -e "  ${BLUE}Region:${NC}            $AWS_REGION"

    if [ -n "$API_URL" ]; then
        echo -e "  ${BLUE}API Gateway URL:${NC}   ${GREEN}$API_URL${NC}"
    fi

    if [ -n "$LAMBDA_ARN" ]; then
        echo -e "  ${BLUE}Lambda Function:${NC}   $LAMBDA_ARN"
    fi

    echo ""

    print_info "AWS Resources created:"
    print_info "  ✓ Lambda Function (container-based)"
    print_info "  ✓ API Gateway (HTTP API)"
    print_info "  ✓ CloudWatch Log Group"
    print_info "  ✓ IAM Role association (LabRole)"
    echo ""

    print_header "Phase 3b: Verify Deployment (Next)"

    print_info "Test the deployed API:"
    if [ "$BACKEND_TYPE" == "demo-backend" ]; then
        print_command "./scripts/aws-ci-cd/32-cd-verify-deployment.sh --demo"
    else
        print_command "./scripts/aws-ci-cd/32-cd-verify-deployment.sh --prod"
    fi
    echo ""

    if [ -n "$API_URL" ]; then
        print_info "Quick manual tests:"
        print_command "curl $API_URL/health"
        print_command "curl -X POST $API_URL/echo -H 'Content-Type: application/json' -d '{\"test\":\"data\"}'"
        echo ""
    fi

    print_header "Useful Commands"

    print_info "View stack in AWS Console:"
    print_info "  1. Open AWS Console → CloudFormation service"
    print_info "  2. Find stack: $STACK_NAME"
    print_info "  3. View Resources, Events, Outputs tabs"
    echo ""

    print_info "View CloudFormation events:"
    print_command "aws cloudformation describe-stack-events \\"
    print_command "    --stack-name $STACK_NAME \\"
    print_command "    --region $AWS_REGION \\"
    print_command "    --max-items 20"
    echo ""

    print_info "View Lambda function details:"
    print_command "aws lambda get-function \\"
    print_command "    --function-name ${STACK_NAME}-FlaskFunction"
    echo ""

    print_info "View CloudWatch logs:"
    print_command "aws logs tail /aws/lambda/${STACK_NAME}-FlaskFunction --follow"
    echo ""

    print_info "Update deployment with new image:"
    print_command "$0 $([ "$BACKEND_TYPE" == "demo-backend" ] && echo "--demo" || echo "--prod") --image-tag <new-tag>"
    echo ""

    print_info "Delete stack (cleanup):"
    print_command "aws cloudformation delete-stack --stack-name $STACK_NAME --region $AWS_REGION"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    show_introduction
    detect_image_tag
    build_sam
    deploy_sam
    get_stack_outputs
    display_summary

    print_success "Phase 3b: CD deployment complete!"
    echo ""
}

# Run main function
main "$@"
