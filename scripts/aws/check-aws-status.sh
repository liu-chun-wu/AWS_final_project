#!/bin/bash

################################################################################
# AWS Resources Status Checker
################################################################################
#
# Purpose: Display current status of all AWS resources
#
# Run this anytime to see what's deployed and how much it costs!
#
################################################################################

set -e

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
            echo "  --demo    Check demo-backend resources"
            echo "  --prod    Check backend (production) resources"
            echo ""
            echo "You MUST specify either --demo or --prod."
            echo ""
            echo "Examples:"
            echo "  $0 --demo   # Check demo backend status"
            echo "  $0 --prod   # Check production backend status"
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
    echo -e "${YELLOW}You must specify which backend to check:${NC}"
    echo ""
    echo "  $0 --demo   # Check demo backend resources"
    echo "  $0 --prod   # Check production backend resources"
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
    echo "  $0 --demo   # Check demo backend"
    echo "  $0 --prod   # Check production backend"
    exit 1
fi

AWS_REGION="us-east-1"
REPOSITORY_NAME="aws-lab-flask-demo"

# Set stack name based on flag
if [ "$USE_DEMO" = true ]; then
    STACK_NAME="flask-demo-backend"
    BACKEND_NAME="demo-backend"
elif [ "$USE_PROD" = true ]; then
    STACK_NAME="flask-prod-backend"
    BACKEND_NAME="backend"
else
    # This should never happen due to validation above
    echo "FATAL ERROR: Invalid backend state"
    exit 1
fi

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "  $1"; }
print_command() { echo -e "${CYAN}  $ $1${NC}"; }

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              AWS RESOURCES STATUS CHECK                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Backend: ${BACKEND_NAME}${NC}"
echo -e "${YELLOW}Stack: ${STACK_NAME}${NC}"
echo ""

# ECR Repository
print_header "ECR Repository Status"

if aws ecr describe-repositories --repository-names ${REPOSITORY_NAME} --region ${AWS_REGION} &>/dev/null; then
    print_success "ECR Repository: EXISTS"
    
    REPO_URI=$(aws ecr describe-repositories --repository-names ${REPOSITORY_NAME} --region ${AWS_REGION} --query 'repositories[0].repositoryUri' --output text)
    echo -e "  ${BLUE}URI:${NC} ${REPO_URI}"
    
    IMAGE_COUNT=$(aws ecr list-images --repository-name ${REPOSITORY_NAME} --region ${AWS_REGION} --query 'length(imageIds)' --output text 2>/dev/null || echo "0")
    echo -e "  ${BLUE}Images:${NC} ${IMAGE_COUNT}"
    
    if [ "$IMAGE_COUNT" -gt 0 ]; then
        print_info "Latest images:"
        aws ecr describe-images --repository-name ${REPOSITORY_NAME} --region ${AWS_REGION} \
            --query 'reverse(sort_by(imageDetails, &imagePushedAt))[:3].[imageTags[0], imageSizeInBytes, imagePushedAt]' \
            --output table 2>/dev/null || true
    fi
    
    print_info "View in console:"
    print_command "aws ecr list-images --repository-name ${REPOSITORY_NAME} --region ${AWS_REGION}"
else
    print_error "ECR Repository: NOT FOUND"
    print_info "Create with: ./scripts/aws/02-setup-ecr.sh"
fi

echo ""

# CloudFormation Stack
print_header "CloudFormation Stack Status"

if aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${AWS_REGION} &>/dev/null; then
    print_success "Stack: EXISTS"
    
    STATUS=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${AWS_REGION} --query 'Stacks[0].StackStatus' --output text)
    echo -e "  ${BLUE}Status:${NC} ${STATUS}"
    
    CREATED=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${AWS_REGION} --query 'Stacks[0].CreationTime' --output text)
    echo -e "  ${BLUE}Created:${NC} ${CREATED}"
    
    print_info "Resources in stack:"
    aws cloudformation list-stack-resources --stack-name ${STACK_NAME} --region ${AWS_REGION} \
        --query 'StackResourceSummaries[].[LogicalResourceId, ResourceType, ResourceStatus]' \
        --output table 2>/dev/null || true
    
    print_info "Stack outputs:"
    aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${AWS_REGION} \
        --query 'Stacks[0].Outputs' --output table 2>/dev/null || true
else
    print_error "Stack: NOT FOUND"
    print_info "Deploy with: ./scripts/aws/04-deploy-sam.sh"
fi

echo ""

# Lambda Function
print_header "Lambda Function Status"

FUNCTION_NAME=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${AWS_REGION} \
    --query 'Stacks[0].Outputs[?OutputKey==`FlaskDemoFunction`].OutputValue' --output text 2>/dev/null | awk -F':' '{print $NF}')

if [ -n "$FUNCTION_NAME" ] && [ "$FUNCTION_NAME" != "None" ]; then
    print_success "Lambda Function: EXISTS"
    
    CONFIG=$(aws lambda get-function-configuration --function-name "${FUNCTION_NAME}" --region ${AWS_REGION} --output json 2>/dev/null)
    
    RUNTIME=$(echo "$CONFIG" | jq -r '.PackageType')
    MEMORY=$(echo "$CONFIG" | jq -r '.MemorySize')
    TIMEOUT=$(echo "$CONFIG" | jq -r '.Timeout')
    LAST_MOD=$(echo "$CONFIG" | jq -r '.LastModified')
    
    echo -e "  ${BLUE}Name:${NC} ${FUNCTION_NAME}"
    echo -e "  ${BLUE}Runtime:${NC} ${RUNTIME}"
    echo -e "  ${BLUE}Memory:${NC} ${MEMORY} MB"
    echo -e "  ${BLUE}Timeout:${NC} ${TIMEOUT} seconds"
    echo -e "  ${BLUE}Last Modified:${NC} ${LAST_MOD}"
    
    print_info "Test function:"
    print_command "aws lambda invoke --function-name ${FUNCTION_NAME} /tmp/output.json"
else
    print_error "Lambda Function: NOT FOUND"
fi

echo ""

# API Gateway
print_header "API Gateway Status"

API_URL=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${AWS_REGION} \
    --query 'Stacks[0].Outputs[?OutputKey==`FlaskDemoApi`].OutputValue' --output text 2>/dev/null)

if [ -n "$API_URL" ] && [ "$API_URL" != "None" ]; then
    print_success "API Gateway: EXISTS"
    
    echo -e "  ${BLUE}Base URL:${NC} ${API_URL}"
    echo -e "  ${BLUE}Health:${NC} ${API_URL}health"
    echo -e "  ${BLUE}Echo:${NC} ${API_URL}echo"
    
    print_info "Test API:"
    print_command "curl ${API_URL}health"
else
    print_error "API Gateway: NOT FOUND"
fi

echo ""

# CloudWatch Logs
print_header "CloudWatch Logs Status"

LOG_GROUP=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${AWS_REGION} \
    --query 'Stacks[0].Outputs[?OutputKey==`FlaskDemoFunctionLogGroup`].OutputValue' --output text 2>/dev/null)

if [ -n "$LOG_GROUP" ] && [ "$LOG_GROUP" != "None" ]; then
    print_success "Log Group: EXISTS"
    
    echo -e "  ${BLUE}Name:${NC} ${LOG_GROUP}"
    
    # Get log streams
    STREAM_COUNT=$(aws logs describe-log-streams --log-group-name "${LOG_GROUP}" --region ${AWS_REGION} \
        --query 'length(logStreams)' --output text 2>/dev/null || echo "0")
    echo -e "  ${BLUE}Log Streams:${NC} ${STREAM_COUNT}"
    
    print_info "View logs:"
    print_command "aws logs tail ${LOG_GROUP} --follow"
else
    print_error "Log Group: NOT FOUND"
fi

echo ""

# Cost Estimate
print_header "Estimated Monthly Costs"

print_info "Based on current resources:"
print_info "  ECR Storage: \$0.10/GB/month × ~0.25GB = \$0.03/month"
print_info "  Lambda: Free tier (1M requests/month)"
print_info "  API Gateway: Free tier (testing usage)"
print_info "  CloudWatch Logs: Free tier (5GB ingestion)"
echo -e "  ${GREEN}Total Estimated: ~\$0.03-0.12/month${NC}"
echo ""

print_info "Get actual costs:"
print_command "aws ce get-cost-and-usage --time-period Start=2025-11-01,End=2025-11-30 --granularity MONTHLY --metrics BlendedCost"

echo ""

# Quick Actions
print_header "Quick Actions"

print_info "Deploy/Update:"
print_command "./scripts/aws/03-build-and-push.sh  # Build & push image"
print_command "./scripts/aws/04-deploy-sam.sh      # Deploy to AWS"

echo ""

print_info "Test:"
print_command "./scripts/aws/05-verify-deployment.sh  # Run all tests"

echo ""

print_info "Clean up:"
print_command "./scripts/aws/99-cleanup-all.sh  # Delete everything"

echo ""
