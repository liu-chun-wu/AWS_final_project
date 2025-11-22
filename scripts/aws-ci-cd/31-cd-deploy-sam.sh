#!/bin/bash
# Script: 31-cd-deploy-sam.sh
# Purpose: Deploy Flask app to AWS Lambda via SAM
# Usage: ./31-cd-deploy-sam.sh [--demo|--prod] [--image-tag <tag>]
#        --image-tag is optional (auto-detects latest from ECR if not provided)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parse arguments
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
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--demo|--prod] [--image-tag <tag>]"
            echo "  --image-tag is optional (auto-detects latest if omitted)"
            exit 1
            ;;
    esac
done

# Only BACKEND_TYPE is required
if [ -z "$BACKEND_TYPE" ]; then
    echo "Usage: $0 [--demo|--prod] [--image-tag <tag>]"
    echo ""
    echo "Options:"
    echo "  --demo        Deploy to demo-backend stack"
    echo "  --prod        Deploy to prod-backend stack"
    echo "  --image-tag   ECR image tag to deploy (optional, auto-detects if omitted)"
    echo ""
    echo "Examples:"
    echo "  $0 --demo                           # Auto-detect latest image"
    echo "  $0 --demo --image-tag manual-test   # Use specific tag"
    exit 1
fi

AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
REPO_NAME="aws-lab-flask-demo"

# Set stack name to match samconfig files
if [ "$BACKEND_TYPE" == "demo-backend" ]; then
    SAM_CONFIG="aws/samconfig-demo.toml"
    STACK_NAME="flask-demo-backend"
else
    SAM_CONFIG="aws/samconfig-prod.toml"
    STACK_NAME="flask-prod-backend"
fi

echo "============================================"
echo "Phase 3b: Manual CD Testing - SAM Deploy"
echo "============================================"
echo "Backend Type: $BACKEND_TYPE"
echo "Stack Name: $STACK_NAME"
echo "SAM Config: $SAM_CONFIG"
echo "Region: $AWS_REGION"
echo ""

# Auto-detect image tag if not provided
if [ -z "$IMAGE_TAG" ]; then
    echo "Step 0: Auto-detecting image from ECR..."

    # Get latest image from ECR
    IMAGE_TAG=$(aws ecr describe-images \
        --repository-name "$REPO_NAME" \
        --region "$AWS_REGION" \
        --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' \
        --output text 2>/dev/null)

    if [ -z "$IMAGE_TAG" ] || [ "$IMAGE_TAG" == "None" ]; then
        echo ""
        echo "❌ No images found in ECR repository: $REPO_NAME"
        echo ""
        echo "╔════════════════════════════════════════════════════════╗"
        echo "║  Phase 3a must be completed first!                    ║"
        echo "╚════════════════════════════════════════════════════════╝"
        echo ""
        echo "Run Phase 3a (Manual CI Testing):"
        if [ "$BACKEND_TYPE" == "demo-backend" ]; then
            echo "  ./scripts/aws-ci-cd/20-ci-build-and-push.sh --demo"
        else
            echo "  ./scripts/aws-ci-cd/20-ci-build-and-push.sh --prod"
        fi
        echo ""
        echo "This will:"
        echo "  1. Run pytest tests"
        echo "  2. Build Docker image"
        echo "  3. Push image to ECR"
        echo ""
        echo "Then retry this command."
        echo ""
        exit 1
    fi

    echo "✅ Auto-detected image tag: $IMAGE_TAG"

    # Show push timestamp
    PUSH_TIME=$(aws ecr describe-images \
        --repository-name "$REPO_NAME" \
        --region "$AWS_REGION" \
        --image-ids imageTag=$IMAGE_TAG \
        --query 'imageDetails[0].imagePushedAt' \
        --output text 2>/dev/null)

    echo "   Pushed at: $PUSH_TIME"
else
    echo "Using specified image tag: $IMAGE_TAG"
fi

echo "Image Tag: $IMAGE_TAG"
echo ""

cd "$PROJECT_ROOT"

# Step 1: Build SAM (skips Docker build since we use pre-built ECR images)
echo "Step 1: Building SAM application..."
sam build --template aws/template.yaml

if [ $? -eq 0 ]; then
    echo "✅ SAM build successful"
else
    echo "❌ SAM build failed"
    exit 1
fi

echo ""

# Step 2: Deploy SAM
echo "Step 2: Deploying to AWS Lambda..."
echo "This may take 3-5 minutes..."
echo ""

sam deploy \
    --config-file "$SAM_CONFIG" \
    --stack-name "$STACK_NAME" \
    --parameter-overrides ImageTag=$IMAGE_TAG \
    --resolve-image-repos \
    --no-confirm-changeset \
    --no-fail-on-empty-changeset \
    --region "$AWS_REGION"

if [ $? -eq 0 ]; then
    echo "✅ SAM deployment successful"
else
    echo "❌ SAM deployment failed"
    exit 1
fi

echo ""

# Step 3: Get deployment outputs
echo "Step 3: Retrieving deployment outputs..."
API_URL=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
    --output text)

LAMBDA_ARN=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`FlaskFunctionArn`].OutputValue' \
    --output text)

echo ""
echo "============================================"
echo "Deployment Complete ✅"
echo "============================================"
echo "Stack Name: $STACK_NAME"
echo "API Gateway URL: $API_URL"
echo "Lambda Function: $LAMBDA_ARN"
echo "Image Tag: $IMAGE_TAG"
echo ""
echo "Next step: Verify deployment"
if [ "$BACKEND_TYPE" == "demo-backend" ]; then
    echo "Run: ./scripts/aws-ci-cd/32-cd-verify-deployment.sh --demo"
else
    echo "Run: ./scripts/aws-ci-cd/32-cd-verify-deployment.sh --prod"
fi
echo ""
echo "Quick tests:"
echo "  curl $API_URL/health"
echo "  curl -X POST $API_URL/echo -H 'Content-Type: application/json' -d '{\"test\":\"data\"}'"
echo ""
