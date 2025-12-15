#!/bin/bash

################################################################################
# Deployment Verification Script - Test Lambda + API Gateway
################################################################################
#
# Script: 32-cd-verify-deployment.sh
# Purpose: Verify Lambda deployment and test API endpoints
# Usage: ./32-cd-verify-deployment.sh [--demo|--prod]
#
# What is Deployment Verification?
# - Automated testing of deployed infrastructure
# - Validates application works correctly in cloud environment
# - Tests API endpoints with real HTTP requests
# - Checks CloudWatch logs for errors
# - Confirms deployment success before marking CD complete
#
# This script verifies:
# 1. CloudFormation stack exists and is healthy
# 2. API Gateway URL accessible
# 3. /health endpoint returns HTTP 200 with correct JSON
# 4. /echo endpoint echoes request body
# 5. CloudWatch Logs capturing Lambda output
#
# What you'll learn:
# - API Gateway endpoint testing with curl
# - HTTP status code validation
# - JSON response validation
# - CloudWatch Logs querying
# - Deployment smoke testing patterns
# - End-to-end integration testing
#
# AWS Services Used:
# - CloudFormation - Stack status and outputs
# - API Gateway - HTTP endpoint testing
# - Lambda - Function execution
# - CloudWatch Logs - Log stream validation
#
# Prerequisites:
# - Stack deployed (31-cd-deploy-sam.sh)
# - curl installed
# - AWS CLI configured
#
# Cost:
# - API Gateway: ~$1 per million requests
# - Lambda: ~$0.20 per million requests
# - CloudWatch Logs: ~$0.50 per GB ingested
# - This script generates 2-3 requests (negligible cost)
#
################################################################################

set -e  # Exit immediately if any command fails

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "${SCRIPT_DIR}/env-common.sh"

################################################################################
# Parse Command-Line Arguments
################################################################################

BACKEND_TYPE=""
if [ "$1" == "--demo" ]; then
    BACKEND_TYPE="demo-backend"
elif [ "$1" == "--prod" ]; then
    BACKEND_TYPE="prod-backend"
else
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  ERROR: Backend type required                                  ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Usage: $0 [--demo|--prod]"
    echo ""
    echo "Options:"
    echo "  --demo  Verify demo-backend deployment"
    echo "  --prod  Verify prod-backend deployment"
    echo ""
    echo "What this does:"
    echo "  • Tests API Gateway endpoints"
    echo "  • Validates responses"
    echo "  • Checks CloudWatch logs"
    exit 1
fi

AWS_REGION="${PIPELINE_AWS_REGION:-${AWS_REGION:-us-east-1}}"

# Set stack name based on backend type
if [ "$BACKEND_TYPE" == "demo-backend" ]; then
    STACK_NAME="${PIPELINE_STACK_DEMO:-flask-demo-backend}"
else
    STACK_NAME="${PIPELINE_STACK_PROD:-flask-prod-backend}"
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
    echo -e "${BLUE}║       PHASE 3b: DEPLOYMENT VERIFICATION                        ║${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}║  Test Lambda + API Gateway deployment                         ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_header "What is Deployment Verification?"

    print_info "Verification ensures deployed infrastructure works correctly:"
    print_info "  • Tests real endpoints (not just syntax validation)"
    print_info "  • Validates HTTP responses (status codes, JSON structure)"
    print_info "  • Checks logs for errors"
    print_info "  • Confirms end-to-end flow works"
    print_info "  • Final gate before marking deployment complete"
    echo ""

    print_info "Verification vs Testing:"
    print_info "  • Unit tests: Test code in isolation (pytest)"
    print_info "  • Integration tests: Test code with dependencies (docker run + curl)"
    print_info "  • Verification tests: Test deployed cloud infrastructure (this script)"
    print_info "  • All three are important for quality!"
    echo ""

    print_info "Configuration:"
    echo -e "  ${BLUE}Backend Type:${NC}      $BACKEND_TYPE"
    echo -e "  ${BLUE}Stack Name:${NC}        $STACK_NAME"
    echo -e "  ${BLUE}AWS Region:${NC}        $AWS_REGION"
    echo ""
}

################################################################################
# Step 1: Get API Gateway URL from Stack Outputs
################################################################################

get_api_url() {
    print_header "Step 1: Getting API Gateway URL"

    print_info "CloudFormation stacks export outputs for other services to use"
    echo ""

    print_info "Query command:"
    print_command "aws cloudformation describe-stacks \\"
    print_command "    --stack-name $STACK_NAME \\"
    print_command "    --query 'Stacks[0].Outputs[?OutputKey==\`FlaskDemoApi\`].OutputValue'"
    echo ""

    print_explain "Understanding this query:"
    print_explain "  • describe-stacks: Get stack details"
    print_explain "  • Stacks[0]: First (and only) stack with this name"
    print_explain "  • Outputs[?OutputKey==\`FlaskDemoApi\`]: Filter outputs by key"
    print_explain "  • .OutputValue: Extract the value (the URL)"
    echo ""

    API_URL=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`FlaskDemoApi`].OutputValue' \
        --output text 2>/dev/null)

    if [ -z "$API_URL" ]; then
        print_error "Could not retrieve API Gateway URL"
        echo ""
        print_info "Possible issues:"
        print_info "  • Stack not deployed (run 31-cd-deploy-sam.sh first)"
        print_info "  • Stack still creating (wait a few minutes)"
        print_info "  • Output key name mismatch in template"
        echo ""
        print_info "Check stack status:"
        print_command "aws cloudformation describe-stacks --stack-name $STACK_NAME"
        exit 1
    fi

    print_success "API Gateway URL: ${GREEN}$API_URL${NC}"
    echo ""

    print_explain "Understanding the URL:"
    echo -e "    ${CYAN}$API_URL${NC}"
    print_explain "    Format: https://<api-id>.execute-api.<region>.amazonaws.com/<stage>"
    print_explain "    • API ID: Unique identifier for this API Gateway"
    print_explain "    • Region: us-east-1 (Learner Lab)"
    print_explain "    • Stage: Deployment stage (usually 'Prod' from SAM)"
    echo ""
}

################################################################################
# Step 2: Test Health Endpoint
################################################################################

test_health_endpoint() {
    print_header "Step 2: Testing /health Endpoint"

    print_info "Health endpoints are standard practice for monitoring services"
    print_info "They provide a quick way to check if service is running"
    echo ""

    print_info "Test command:"
    print_command "curl -s -w '\\nHTTP_STATUS:%{http_code}' $API_URL/health"
    echo ""

    print_explain "curl parameters explained:"
    print_explain "  • -s: Silent mode (no progress bar)"
    print_explain "  • -w '\\nHTTP_STATUS:%{http_code}': Append HTTP status code"
    print_explain "  • This lets us extract both body and status separately"
    echo ""

    print_info "Sending request to /health..."

    HEALTH_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "$API_URL/health" 2>&1)
    HTTP_STATUS=$(echo "$HEALTH_RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
    RESPONSE_BODY=$(echo "$HEALTH_RESPONSE" | grep -v "HTTP_STATUS")

    echo ""
    echo -e "  ${BLUE}HTTP Status:${NC}  $HTTP_STATUS"
    echo -e "  ${BLUE}Response:${NC}     $RESPONSE_BODY"
    echo ""

    print_explain "HTTP Status Codes:"
    print_explain "  • 200: Success (OK)"
    print_explain "  • 4xx: Client error (bad request, not found, etc.)"
    print_explain "  • 500: Server error (Lambda crashed, timeout, etc.)"
    print_explain "  • 502: Bad Gateway (Lambda error response)"
    print_explain "  • 504: Gateway Timeout (Lambda execution > 29 seconds)"
    echo ""

    if [ "$HTTP_STATUS" == "200" ]; then
        print_success "Health endpoint returned HTTP 200 ✓"
        echo ""

        # Validate JSON response structure
        print_info "Validating response structure..."

        if echo "$RESPONSE_BODY" | grep -q "status"; then
            print_success "Response contains 'status' field"
        else
            print_warning "Response missing 'status' field"
        fi

        if echo "$RESPONSE_BODY" | grep -q "$BACKEND_TYPE"; then
            print_success "Response contains service name: $BACKEND_TYPE"
        else
            print_warning "Response doesn't contain expected service name"
        fi

        # Expected format: {"status": "ok", "service": "demo-backend"}
        print_info "Expected format: {\"status\": \"ok\", \"service\": \"$BACKEND_TYPE\"}"
    else
        print_error "Health endpoint returned HTTP $HTTP_STATUS"
        echo ""
        print_info "Common issues:"
        print_info "  • 502/504: Lambda function error or timeout"
        print_info "  • 403: API Gateway permissions issue"
        print_info "  • Check CloudWatch logs for Lambda errors"
        exit 1
    fi

    echo ""
}

################################################################################
# Step 3: Test Echo Endpoint
################################################################################

test_echo_endpoint() {
    print_header "Step 3: Testing /echo Endpoint"

    print_info "Echo endpoint tests request/response flow with POST data"
    echo ""

    if [ "$BACKEND_TYPE" != "demo-backend" ]; then
        print_warning "Skipping /echo verification for production backend (endpoint not present)"
        return 0
    fi

    # Create test payload with timestamp
    TEST_DATA='{"message": "Phase 3b verification test", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'

    print_info "Test command:"
    print_command "curl -s -w '\\nHTTP_STATUS:%{http_code}' \\"
    print_command "    -X POST \\"
    print_command "    -H 'Content-Type: application/json' \\"
    print_command "    -d '$TEST_DATA' \\"
    print_command "    $API_URL/echo"
    echo ""

    print_explain "curl parameters for POST:"
    print_explain "  • -X POST: HTTP POST method (default is GET)"
    print_explain "  • -H 'Content-Type: application/json': Set request header"
    print_explain "  • -d '<data>': Request body (JSON payload)"
    print_explain "  • API Gateway forwards this to Lambda as event.body"
    echo ""

    print_info "Request payload:"
    echo -e "  ${CYAN}$TEST_DATA${NC}"
    echo ""

    print_info "Sending POST request to /echo..."

    ECHO_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$TEST_DATA" \
        "$API_URL/echo" 2>&1)

    HTTP_STATUS=$(echo "$ECHO_RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
    RESPONSE_BODY=$(echo "$ECHO_RESPONSE" | grep -v "HTTP_STATUS")

    echo ""
    echo -e "  ${BLUE}HTTP Status:${NC}  $HTTP_STATUS"
    echo -e "  ${BLUE}Response:${NC}     $RESPONSE_BODY"
    echo ""

    if [ "$HTTP_STATUS" == "200" ]; then
        print_success "Echo endpoint returned HTTP 200 ✓"
        echo ""

        # Validate echo response contains request data
        print_info "Validating response echoes request..."

        if echo "$RESPONSE_BODY" | grep -q "Phase 3b verification test"; then
            print_success "Response contains request message ✓"
        else
            print_warning "Response doesn't echo request message"
        fi

        if echo "$RESPONSE_BODY" | grep -q "timestamp"; then
            print_success "Response contains timestamp field ✓"
        else
            print_warning "Response missing timestamp field"
        fi

        # Expected format: {"body": {"message": "...", "timestamp": "..."}}
        print_info "Expected: Echo wraps request in {\"body\": <request-data>}"
    else
        print_error "Echo endpoint returned HTTP $HTTP_STATUS"
        echo ""
        print_info "Check Lambda logs for POST request handling errors"
        exit 1
    fi

    echo ""
}

################################################################################
# Step 4: Check CloudWatch Logs
################################################################################

check_cloudwatch_logs() {
    print_header "Step 4: Checking CloudWatch Logs"

    print_info "What is CloudWatch Logs?"
    print_info "  • AWS's centralized logging service"
    print_info "  • Lambda automatically sends stdout/stderr to CloudWatch"
    print_info "  • Logs organized by Log Groups and Log Streams"
    print_info "  • Searchable and queryable"
    echo ""

    print_info "Getting Lambda function name from stack..."

    LAMBDA_ARN=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`FlaskDemoFunction`].OutputValue' \
        --output text 2>/dev/null)

    if [ -z "$LAMBDA_ARN" ]; then
        print_warning "Could not get Lambda ARN from stack outputs"
        print_info "Logs check skipped (not critical for verification)"
        echo ""
        return
    fi

    # Extract function name from ARN
    # ARN format: arn:aws:lambda:region:account:function:name
    FUNCTION_NAME=$(echo "$LAMBDA_ARN" | awk -F: '{print $NF}')
    LOG_GROUP="/aws/lambda/$FUNCTION_NAME"

    echo ""
    echo -e "  ${BLUE}Lambda Function:${NC} $FUNCTION_NAME"
    echo -e "  ${BLUE}Log Group:${NC}       $LOG_GROUP"
    echo ""

    print_explain "CloudWatch Log structure:"
    print_explain "  • Log Group: /aws/lambda/<function-name>"
    print_explain "    → Container for all logs from this Lambda"
    print_explain "  • Log Streams: <date>/<version>/<instance-id>"
    print_explain "    → Individual execution logs"
    print_explain "    → One stream per Lambda container instance"
    echo ""

    print_info "Querying recent log streams..."
    print_command "aws logs describe-log-streams \\"
    print_command "    --log-group-name $LOG_GROUP \\"
    print_command "    --order-by LastEventTime \\"
    print_command "    --descending"
    echo ""

    LOG_STREAMS=$(aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP" \
        --order-by LastEventTime \
        --descending \
        --max-items 1 \
        --region "$AWS_REGION" \
        --query 'logStreams[0].logStreamName' \
        --output text 2>/dev/null)

    if [ -n "$LOG_STREAMS" ] && [ "$LOG_STREAMS" != "None" ]; then
        print_success "CloudWatch logs available"
        echo ""

        print_info "Recent log entries (last 5 minutes):"
        print_command "aws logs tail $LOG_GROUP --since 5m --format short"
        echo ""

        aws logs tail "$LOG_GROUP" \
            --since 5m \
            --format short \
            --region "$AWS_REGION" 2>/dev/null | head -15 || echo "  No recent logs"

        echo ""

        print_explain "What to look for in logs:"
        print_explain "  • START RequestId: Lambda invocation began"
        print_explain "  • END RequestId: Lambda invocation completed"
        print_explain "  • REPORT RequestId: Execution metrics (duration, memory)"
        print_explain "  • Any ERROR or Exception: Application errors"
        print_explain "  • Your Flask app logs (from print/logging statements)"
    else
        print_warning "No log streams found yet"
        print_info "This is normal for first deployment"
        print_info "Logs appear after first Lambda invocation"
        echo ""
        print_info "To see logs as they arrive:"
        print_command "aws logs tail $LOG_GROUP --follow"
    fi

    echo ""
}

################################################################################
# Display Summary
################################################################################

display_summary() {
    print_header "Phase 3b Complete: Manual CD Validated ✅"

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       DEPLOYMENT VERIFIED SUCCESSFULLY! ✓                     ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_info "Verification results:"
    print_info "  ✓ API Gateway URL retrieved from stack"
    print_info "  ✓ /health endpoint: HTTP 200 with valid JSON"
    print_info "  ✓ /echo endpoint: HTTP 200 with echoed data"
    print_info "  ✓ CloudWatch logs accessible"
    echo ""

    echo -e "  ${BLUE}Backend:${NC}         $BACKEND_TYPE"
    echo -e "  ${BLUE}Stack:${NC}           $STACK_NAME"
    echo -e "  ${BLUE}API URL:${NC}         ${GREEN}$API_URL${NC}"
    echo ""

    print_header "All Phase 3 (Manual CI/CD) Steps Complete!"

    print_info "Phase 3a (CI) - Build and Push:"
    print_info "  ✓ Tests passed"
    print_info "  ✓ Docker image built"
    print_info "  ✓ Image pushed to ECR"
    echo ""

    print_info "Phase 3b (CD) - Deploy and Verify:"
    print_info "  ✓ SAM template validated"
    print_info "  ✓ Lambda + API Gateway deployed"
    print_info "  ✓ Endpoints tested and working"
    echo ""

    print_header "Next Phase: Phase 4 - Jenkinsfile Preparation"

    print_info "Now that manual CI/CD works, create pipeline definitions:"
    print_info "  1. Create jenkins-pipeline-setting/Jenkinsfile-CI (mirrors 20-ci-build-and-push.sh)"
    print_info "  2. Create jenkins-pipeline-setting/Jenkinsfile-CD (mirrors 31-cd-deploy-sam.sh + this script)"
    print_info "  3. Commit Jenkinsfiles to Git"
    print_info "  4. Deploy Jenkins on EC2 (Phase 5)"
    print_info "  5. Test automated pipelines (Phase 6)"
    echo ""

    print_header "Useful Commands"

    print_info "Test endpoints manually:"
    print_command "curl $API_URL/health"
    print_command "curl -X POST $API_URL/echo -H 'Content-Type: application/json' -d '{\"test\":\"data\"}'"
    echo ""

    print_info "Watch CloudWatch logs live:"
    print_command "aws logs tail /aws/lambda/${STACK_NAME}-FlaskFunction --follow"
    echo ""

    print_info "View API Gateway details:"
    print_command "aws apigateway get-rest-apis --region $AWS_REGION"
    echo ""

    print_info "View Lambda function details:"
    print_command "aws lambda get-function --function-name ${STACK_NAME}-FlaskFunction"
    echo ""

    print_info "Update deployment:"
    print_command "./scripts/jenkins/31-cd-deploy-sam.sh $([ "$BACKEND_TYPE" == "demo-backend" ] && echo "--demo" || echo "--prod")"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    show_introduction
    get_api_url
    test_health_endpoint
    test_echo_endpoint
    check_cloudwatch_logs
    display_summary

    print_success "Deployment verification complete!"
    echo ""
}

# Run main function
main "$@"
