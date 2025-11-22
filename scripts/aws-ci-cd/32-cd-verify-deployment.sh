#!/bin/bash
# Script: 32-cd-verify-deployment.sh
# Purpose: Verify Lambda deployment and test endpoints
# Usage: ./32-cd-verify-deployment.sh [--demo|--prod]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parse arguments
BACKEND_TYPE=""
if [ "$1" == "--demo" ]; then
    BACKEND_TYPE="demo-backend"
elif [ "$1" == "--prod" ]; then
    BACKEND_TYPE="prod-backend"
else
    echo "Usage: $0 [--demo|--prod]"
    exit 1
fi

AWS_REGION="${AWS_REGION:-us-east-1}"

# Set stack name to match samconfig files
if [ "$BACKEND_TYPE" == "demo-backend" ]; then
    STACK_NAME="flask-demo-backend"
else
    STACK_NAME="flask-prod-backend"
fi

echo "============================================"
echo "Phase 3b: Deployment Verification"
echo "============================================"
echo "Backend Type: $BACKEND_TYPE"
echo "Stack Name: $STACK_NAME"
echo ""

# Step 1: Get API Gateway URL
echo "Step 1: Getting API Gateway URL..."
API_URL=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`FlaskDemoApi`].OutputValue' \
    --output text 2>/dev/null)

if [ -z "$API_URL" ]; then
    echo "❌ Could not retrieve API Gateway URL"
    echo "Stack may not be deployed. Run 31-cd-deploy-sam.sh first"
    exit 1
fi

echo "✅ API Gateway URL: $API_URL"
echo ""

# Step 2: Test health endpoint
echo "Step 2: Testing /health endpoint..."
HEALTH_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "$API_URL/health")
HTTP_STATUS=$(echo "$HEALTH_RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
RESPONSE_BODY=$(echo "$HEALTH_RESPONSE" | grep -v "HTTP_STATUS")

echo "HTTP Status: $HTTP_STATUS"
echo "Response: $RESPONSE_BODY"

if [ "$HTTP_STATUS" == "200" ]; then
    echo "✅ Health endpoint working"

    # Check if response contains expected fields
    if echo "$RESPONSE_BODY" | grep -q "status" && echo "$RESPONSE_BODY" | grep -q "$BACKEND_TYPE"; then
        echo "✅ Response contains expected service name: $BACKEND_TYPE"
    else
        echo "⚠️  Response doesn't match expected format"
    fi
else
    echo "❌ Health endpoint returned HTTP $HTTP_STATUS"
    exit 1
fi

echo ""

# Step 3: Test echo endpoint
echo "Step 3: Testing /echo endpoint..."
TEST_DATA='{"message": "Phase 3b verification test", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'

ECHO_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$TEST_DATA" \
    "$API_URL/echo")

HTTP_STATUS=$(echo "$ECHO_RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
RESPONSE_BODY=$(echo "$ECHO_RESPONSE" | grep -v "HTTP_STATUS")

echo "HTTP Status: $HTTP_STATUS"
echo "Request: $TEST_DATA"
echo "Response: $RESPONSE_BODY"

if [ "$HTTP_STATUS" == "200" ]; then
    echo "✅ Echo endpoint working"

    # Check if response echoes back the data
    if echo "$RESPONSE_BODY" | grep -q "Phase 3b verification test"; then
        echo "✅ Response echoes request body correctly"
    else
        echo "⚠️  Response doesn't echo request properly"
    fi
else
    echo "❌ Echo endpoint returned HTTP $HTTP_STATUS"
    exit 1
fi

echo ""

# Step 4: Check CloudWatch logs
echo "Step 4: Checking CloudWatch logs..."
LAMBDA_ARN=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`FlaskDemoFunction`].OutputValue' \
    --output text 2>/dev/null)

FUNCTION_NAME=$(echo "$LAMBDA_ARN" | awk -F: '{print $NF}')
LOG_GROUP="/aws/lambda/$FUNCTION_NAME"

echo "Log Group: $LOG_GROUP"

LOG_STREAMS=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP" \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --region "$AWS_REGION" \
    --query 'logStreams[0].logStreamName' \
    --output text 2>/dev/null)

if [ -n "$LOG_STREAMS" ] && [ "$LOG_STREAMS" != "None" ]; then
    echo "✅ CloudWatch logs available"
    echo ""
    echo "Recent log entries:"
    aws logs tail "$LOG_GROUP" \
        --since 5m \
        --format short \
        --region "$AWS_REGION" 2>/dev/null | head -10 || echo "No recent logs"
else
    echo "⚠️  No log streams found yet (normal for first deployment)"
fi

echo ""
echo "============================================"
echo "Phase 3b Complete: Manual CD Validated ✅"
echo "============================================"
echo "Backend: $BACKEND_TYPE"
echo "API URL: $API_URL"
echo "Health: $API_URL/health"
echo "Echo: $API_URL/echo"
echo ""
echo "All Phase 3 (Manual CI/CD) steps validated!"
echo ""
echo "Next Phase: Phase 4 - Jenkinsfile Preparation"
echo "Create Jenkinsfile-CI and Jenkinsfile-CD that mirror these scripts"
echo ""
