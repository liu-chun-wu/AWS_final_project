#!/bin/bash

################################################################################
# AWS Deployment Verification Script
################################################################################
#
# Purpose: Test and verify AWS Lambda deployment
#
# This script:
# - Tests /health endpoint (3 consecutive calls - success criteria)
# - Tests /echo endpoint with JSON payload
# - Checks Lambda function configuration
# - Views CloudWatch logs
# - Validates all deployment success criteria
#
# What you'll learn:
# - How to test API Gateway endpoints with curl
# - How to view Lambda function details
# - How to read CloudWatch logs
# - How to filter logs by pattern
# - Understanding Lambda cold starts vs warm starts
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
            echo "  --demo    Verify demo-backend deployment"
            echo "  --prod    Verify backend (production) deployment"
            echo ""
            echo "You MUST specify either --demo or --prod."
            echo ""
            echo "Examples:"
            echo "  $0 --demo   # Verify demo backend deployment"
            echo "  $0 --prod   # Verify production backend deployment"
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
    echo -e "${YELLOW}You must specify which deployment to verify:${NC}"
    echo ""
    echo "  $0 --demo   # Verify demo backend deployment"
    echo "  $0 --prod   # Verify production backend deployment"
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
    echo "  $0 --demo   # Verify demo backend"
    echo "  $0 --prod   # Verify production backend"
    exit 1
fi

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AWS_REGION="us-east-1"

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

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

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
# Step 1: Get Stack Outputs
################################################################################

get_stack_outputs() {
    print_header "Step 1: Getting Deployment Information"

    print_info "Retrieving CloudFormation stack outputs..."
    echo ""

    print_info "Command to get stack outputs:"
    print_command "aws cloudformation describe-stacks \\"
    print_command "  --stack-name ${STACK_NAME} \\"
    print_command "  --region ${AWS_REGION}"
    echo ""

    # Check if stack exists
    if ! aws cloudformation describe-stacks \
        --stack-name ${STACK_NAME} \
        --region ${AWS_REGION} \
        &> /dev/null; then

        print_error "Stack '${STACK_NAME}' not found"
        print_info "You need to deploy first"
        print_info "Run: ./scripts/aws/04-deploy-sam.sh"
        exit 1
    fi

    # Get outputs
    OUTPUTS=$(aws cloudformation describe-stacks \
        --stack-name ${STACK_NAME} \
        --region ${AWS_REGION} \
        --query 'Stacks[0].Outputs' \
        --output json)

    # Extract URLs and ARNs
    API_URL=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="FlaskDemoApi") | .OutputValue' 2>/dev/null)
    HEALTH_URL=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="HealthEndpoint") | .OutputValue' 2>/dev/null)
    ECHO_URL=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="EchoEndpoint") | .OutputValue' 2>/dev/null)
    FUNCTION_ARN=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="FlaskDemoFunction") | .OutputValue' 2>/dev/null)
    LOG_GROUP=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="FlaskDemoFunctionLogGroup") | .OutputValue' 2>/dev/null)

    print_success "Retrieved deployment information"
    echo ""
    echo -e "  ${BLUE}API URL:${NC}        ${API_URL}"
    echo -e "  ${BLUE}Health URL:${NC}     ${HEALTH_URL}"
    echo -e "  ${BLUE}Echo URL:${NC}       ${ECHO_URL}"
    echo -e "  ${BLUE}Function ARN:${NC}   ${FUNCTION_ARN}"
    echo -e "  ${BLUE}Log Group:${NC}      ${LOG_GROUP}"
    echo ""
}

################################################################################
# Step 2: Test Health Endpoint (3x - Success Criteria)
################################################################################

test_health_endpoint() {
    print_header "Step 2: Testing /health Endpoint (Success Criteria)"

    print_info "Success Criteria: /health must return HTTP 200 three consecutive times"
    echo ""

    print_info "Command to test endpoint:"
    print_command "curl -s -w '\\n%{http_code}' ${HEALTH_URL}"
    print_explain "  -s = silent mode (no progress bar)"
    print_explain "  -w '\\n%{http_code}' = append HTTP status code to output"
    echo ""

    for i in {1..3}; do
        print_info "Test ${i}/3: Calling ${HEALTH_URL}"

        RESPONSE=$(curl -s -w "\n%{http_code}" "${HEALTH_URL}")
        HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
        BODY=$(echo "$RESPONSE" | head -n-1)

        if [ "$HTTP_CODE" = "200" ]; then
            print_success "Test ${i}/3 passed (HTTP ${HTTP_CODE})"
            echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            print_error "Test ${i}/3 failed (HTTP ${HTTP_CODE})"
            print_info "Response: ${BODY}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi

        echo ""

        # Small delay between tests
        if [ $i -lt 3 ]; then
            sleep 1
        fi
    done

    if [ $TESTS_FAILED -eq 0 ]; then
        print_success "✓ Success Criteria Met: /health endpoint passed all 3 tests"
    else
        print_error "✗ Success Criteria Failed: ${TESTS_FAILED}/3 tests failed"
    fi

    echo ""
}

################################################################################
# Step 3: Test Echo Endpoint
################################################################################

test_echo_endpoint() {
    print_header "Step 3: Testing /echo Endpoint"

    print_info "The /echo endpoint should return the JSON body we send to it"
    echo ""

    print_info "Command to test endpoint:"
    print_command "curl -X POST ${ECHO_URL} \\"
    print_command "  -H 'Content-Type: application/json' \\"
    print_command "  -d '{\"test\": \"deployment\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}'"
    echo ""

    print_explain "  -X POST = HTTP POST method"
    print_explain "  -H = Set Content-Type header to application/json"
    print_explain "  -d = Request body (JSON data)"
    echo ""

    TEST_PAYLOAD='{"test": "deployment", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'", "message": "Hello from AWS Lambda!"}'

    print_info "Sending test payload:"
    echo "$TEST_PAYLOAD" | jq '.' 2>/dev/null || echo "$TEST_PAYLOAD"
    echo ""

    print_info "Calling ${ECHO_URL}"

    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -X POST "${ECHO_URL}" \
        -H 'Content-Type: application/json' \
        -d "$TEST_PAYLOAD")

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n-1)

    if [ "$HTTP_CODE" = "200" ]; then
        print_success "Echo endpoint test passed (HTTP ${HTTP_CODE})"

        print_info "Response received:"
        echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"

        # Verify the response contains our test data
        if echo "$BODY" | grep -q "deployment"; then
            print_success "✓ Response contains expected data"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            print_warning "Response doesn't contain expected test data"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        print_error "Echo endpoint test failed (HTTP ${HTTP_CODE})"
        print_info "Response: ${BODY}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    echo ""
}

################################################################################
# Step 4: Check Lambda Function Details
################################################################################

check_lambda_details() {
    print_header "Step 4: Checking Lambda Function Configuration"

    print_info "Viewing Lambda function details..."
    echo ""

    # Extract function name from ARN
    FUNCTION_NAME=$(echo "$FUNCTION_ARN" | awk -F':' '{print $NF}')

    print_info "Command to get function configuration:"
    print_command "aws lambda get-function-configuration \\"
    print_command "  --function-name ${FUNCTION_NAME} \\"
    print_command "  --region ${AWS_REGION}"
    echo ""

    print_explain "This shows:"
    print_explain "  - Runtime (should be container image)"
    print_explain "  - Memory allocated to function"
    print_explain "  - Timeout setting"
    print_explain "  - Last update time"
    print_explain "  - Container image URI"
    echo ""

    CONFIG=$(aws lambda get-function-configuration \
        --function-name "${FUNCTION_NAME}" \
        --region ${AWS_REGION} \
        --output json)

    # Extract key details
    RUNTIME=$(echo "$CONFIG" | jq -r '.PackageType' 2>/dev/null)
    MEMORY=$(echo "$CONFIG" | jq -r '.MemorySize' 2>/dev/null)
    TIMEOUT=$(echo "$CONFIG" | jq -r '.Timeout' 2>/dev/null)
    LAST_MODIFIED=$(echo "$CONFIG" | jq -r '.LastModified' 2>/dev/null)
    IMAGE_URI=$(echo "$CONFIG" | jq -r '.CodeSha256' 2>/dev/null)

    print_info "Lambda Function Configuration:"
    echo -e "  ${BLUE}Function Name:${NC}   ${FUNCTION_NAME}"
    echo -e "  ${BLUE}Package Type:${NC}    ${RUNTIME}"
    echo -e "  ${BLUE}Memory:${NC}          ${MEMORY} MB"
    echo -e "  ${BLUE}Timeout:${NC}         ${TIMEOUT} seconds"
    echo -e "  ${BLUE}Last Modified:${NC}   ${LAST_MODIFIED}"

    if [ "$RUNTIME" = "Image" ]; then
        print_success "✓ Function is using container image (correct)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        print_warning "Function is not using container image"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    echo ""
}

################################################################################
# Step 5: View CloudWatch Logs
################################################################################

view_cloudwatch_logs() {
    print_header "Step 5: Viewing CloudWatch Logs (Success Criteria)"

    print_info "Success Criteria: CloudWatch logs must show recent requests"
    echo ""

    print_info "Command to tail logs:"
    print_command "aws logs tail ${LOG_GROUP} --since 10m --region ${AWS_REGION}"
    print_explain "  --since 10m = Show logs from last 10 minutes"
    print_explain "  --follow = Keep connection open for new logs (not used here)"
    echo ""

    print_info "Fetching recent logs..."
    echo ""

    # Get logs from last 10 minutes
    LOGS=$(aws logs tail "${LOG_GROUP}" \
        --since 10m \
        --region ${AWS_REGION} \
        --format short 2>/dev/null || echo "")

    if [ -z "$LOGS" ]; then
        print_warning "No recent logs found"
        print_info "This might mean:"
        print_info "  1. Function hasn't been called recently"
        print_info "  2. Logs are still being written (can take 10-30 seconds)"
        print_info "  3. Log group permissions issue"
        echo ""

        print_info "Waiting 10 seconds for logs to appear..."
        sleep 10

        LOGS=$(aws logs tail "${LOG_GROUP}" \
            --since 10m \
            --region ${AWS_REGION} \
            --format short 2>/dev/null || echo "")
    fi

    if [ -n "$LOGS" ]; then
        print_success "✓ Found recent logs in CloudWatch"

        print_info "Recent log entries (last 20 lines):"
        echo "$LOGS" | tail -n 20

        # Check if logs contain /health or /echo
        if echo "$LOGS" | grep -q -E "/health|/echo"; then
            print_success "✓ Success Criteria Met: Logs show endpoint requests"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            print_warning "Logs don't show /health or /echo requests yet"
            print_info "Try running this script again in a few seconds"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        print_warning "No logs available yet"
        print_info "Logs can take up to 30 seconds to appear in CloudWatch"
        print_info "Run this script again in a moment"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    echo ""

    print_info "To view logs in real-time:"
    print_command "aws logs tail ${LOG_GROUP} --follow --region ${AWS_REGION}"
    echo ""

    print_info "To filter logs by pattern:"
    print_command "aws logs tail ${LOG_GROUP} --filter-pattern 'ERROR' --region ${AWS_REGION}"
    echo ""
}

################################################################################
# Step 6: Performance Metrics
################################################################################

check_performance_metrics() {
    print_header "Step 6: Lambda Performance Insights"

    print_info "Understanding Lambda cold starts vs warm starts..."
    echo ""

    # Extract function name
    FUNCTION_NAME=$(echo "$FUNCTION_ARN" | awk -F':' '{print $NF}')

    print_info "Command to get recent invocations:"
    print_command "aws lambda get-function --function-name ${FUNCTION_NAME}"
    echo ""

    print_explain "Lambda Performance Concepts:"
    print_explain "  - Cold Start: First invocation or after idle period"
    print_explain "    • Lambda downloads container image"
    print_explain "    • Starts container"
    print_explain "    • Runs initialization code"
    print_explain "    • Response time: 1-3 seconds (typical)"
    print_explain ""
    print_explain "  - Warm Start: Subsequent invocations"
    print_explain "    • Container already running"
    print_explain "    • No initialization needed"
    print_explain "    • Response time: 50-200ms (typical)"
    echo ""

    print_info "For better cold start performance:"
    print_info "  - Minimize Docker image size"
    print_info "  - Use multi-stage builds"
    print_info "  - Avoid heavy dependencies in initialization"
    print_info "  - Consider Lambda provisioned concurrency (costs money)"
    echo ""
}

################################################################################
# Step 7: Display Summary
################################################################################

display_summary() {
    print_header "Verification Summary"

    TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))

    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}║          ALL VERIFICATION TESTS PASSED! ✓                      ║${NC}"
    else
        echo -e "${YELLOW}║          SOME TESTS FAILED                                     ║${NC}"
    fi
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "  ${BLUE}Tests Passed:${NC}  ${GREEN}${TESTS_PASSED}${NC}/${TOTAL_TESTS}"
    echo -e "  ${BLUE}Tests Failed:${NC}  ${RED}${TESTS_FAILED}${NC}/${TOTAL_TESTS}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        print_success "✓ /health endpoint: 3/3 consecutive success (SUCCESS CRITERIA MET)"
        print_success "✓ /echo endpoint: Returned correct data"
        print_success "✓ Lambda function: Using container image"
        print_success "✓ CloudWatch logs: Showing recent requests (SUCCESS CRITERIA MET)"
        echo ""
        echo -e "${GREEN}Your Flask application is fully deployed and working!${NC}"
    else
        print_info "Some tests need attention. Common issues:"
        print_info "  - Logs take time to appear (wait 30 seconds, run again)"
        print_info "  - First request may be slow (cold start)"
        print_info "  - Check Lambda function errors in CloudWatch"
    fi

    echo ""
}

################################################################################
# Step 8: Next Steps
################################################################################

display_next_steps() {
    print_header "Next Steps"

    print_info "Your API is live! Here's how to use it:"
    echo ""

    print_info "Test health endpoint:"
    echo -e "  ${BLUE}curl ${HEALTH_URL}${NC}"
    echo ""

    print_info "Test echo endpoint:"
    echo -e "  ${BLUE}curl -X POST ${ECHO_URL} \\${NC}"
    echo -e "  ${BLUE}  -H 'Content-Type: application/json' \\${NC}"
    echo -e "  ${BLUE}  -d '{\"your\": \"data here\"}'${NC}"
    echo ""

    print_info "Monitor logs in real-time:"
    echo -e "  ${BLUE}aws logs tail ${LOG_GROUP} --follow${NC}"
    echo ""

    print_info "Check all AWS resources:"
    print_command "./scripts/aws/check-aws-status.sh"
    echo ""

    print_info "Update deployment after code changes:"
    print_info "  1. ./scripts/aws/03-build-and-push.sh  # Push new image"
    print_info "  2. ./scripts/aws/04-deploy-sam.sh      # Update Lambda"
    print_info "  3. ./scripts/aws/05-verify-deployment.sh  # Verify again"
    echo ""

    print_info "Clean up all resources:"
    print_command "./scripts/aws/99-cleanup-all.sh"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          AWS DEPLOYMENT VERIFICATION                           ║${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}║  Tests endpoints, checks logs, validates success criteria      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Backend: ${BACKEND_NAME}${NC}"
    echo -e "${YELLOW}Stack: ${STACK_NAME}${NC}"
    echo ""

    get_stack_outputs
    test_health_endpoint
    test_echo_endpoint
    check_lambda_details
    view_cloudwatch_logs
    check_performance_metrics
    display_summary
    display_next_steps

    if [ $TESTS_FAILED -eq 0 ]; then
        print_success "Verification complete - all tests passed!"
        exit 0
    else
        print_warning "Verification complete - some tests failed"
        exit 1
    fi
}

# Run main function
main "$@"
