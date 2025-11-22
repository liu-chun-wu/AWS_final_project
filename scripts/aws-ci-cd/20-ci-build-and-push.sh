#!/bin/bash
# Script: 20-ci-build-and-push.sh
# Purpose: Manual CI testing - Build Docker image and push to ECR
# Usage: ./20-ci-build-and-push.sh [--demo|--prod]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parse arguments
BACKEND_TYPE=""
if [ "$1" == "--demo" ]; then
    BACKEND_TYPE="demo-backend"
    BACKEND_DIR="demo-backend"
elif [ "$1" == "--prod" ]; then
    BACKEND_TYPE="prod-backend"
    BACKEND_DIR="backend"
else
    echo "Usage: $0 [--demo|--prod]"
    echo "  --demo  Build and push demo-backend"
    echo "  --prod  Build and push production backend"
    exit 1
fi

AWS_REGION="${AWS_REGION:-us-east-1}"
REPO_NAME="aws-lab-flask-demo"
IMAGE_TAG="${IMAGE_TAG:-manual-test}"

echo "============================================"
echo "Phase 3a: Manual CI Testing"
echo "============================================"
echo "Backend Type: $BACKEND_TYPE"
echo "Backend Directory: $BACKEND_DIR"
echo "Image Tag: $IMAGE_TAG"
echo "Region: $AWS_REGION"
echo ""

# Step 1: Run tests
echo "Step 1: Running tests..."
cd "$PROJECT_ROOT/$BACKEND_DIR"

if [ -f "requirements.txt" ]; then
    echo "Installing dependencies..."
    pip install -q -r requirements.txt
fi

if [ -d "tests" ]; then
    echo "Running pytest..."
    pytest tests -v
    if [ $? -eq 0 ]; then
        echo "✅ All tests passed"
    else
        echo "❌ Tests failed"
        exit 1
    fi
else
    echo "⚠️  No tests directory found, skipping tests"
fi

echo ""

# Step 2: Build Docker image
echo "Step 2: Building Docker image..."
cd "$PROJECT_ROOT"

docker build --platform linux/amd64 --provenance=false --sbom=false -t aws-lab-flask-demo:$IMAGE_TAG $BACKEND_DIR/
if [ $? -eq 0 ]; then
    echo "✅ Docker image built successfully"
else
    echo "❌ Docker build failed"
    exit 1
fi

echo ""

# Step 3: Get ECR repository URI
echo "Step 3: Getting ECR repository URI..."
ECR_REPO_URI=$(aws ecr describe-repositories \
    --repository-names "$REPO_NAME" \
    --region "$AWS_REGION" \
    --query 'repositories[0].repositoryUri' \
    --output text 2>/dev/null)

if [ -z "$ECR_REPO_URI" ]; then
    echo "❌ ECR repository not found. Run 11-setup-ecr.sh first"
    exit 1
fi

echo "ECR Repository: $ECR_REPO_URI"
echo ""

# Step 4: Login to ECR
echo "Step 4: Logging into ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
    docker login --username AWS --password-stdin "$ECR_REPO_URI"

if [ $? -eq 0 ]; then
    echo "✅ ECR login successful"
else
    echo "❌ ECR login failed"
    exit 1
fi

echo ""

# Step 5: Tag image for ECR
echo "Step 5: Tagging image for ECR..."
docker tag aws-lab-flask-demo:$IMAGE_TAG $ECR_REPO_URI:$IMAGE_TAG
docker tag aws-lab-flask-demo:$IMAGE_TAG $ECR_REPO_URI:latest

echo "✅ Image tagged:"
echo "  - $ECR_REPO_URI:$IMAGE_TAG"
echo "  - $ECR_REPO_URI:latest"
echo ""

# Step 6: Push to ECR
echo "Step 6: Pushing to ECR..."
docker push $ECR_REPO_URI:$IMAGE_TAG
docker push $ECR_REPO_URI:latest

if [ $? -eq 0 ]; then
    echo "✅ Image pushed to ECR successfully"
else
    echo "❌ Push to ECR failed"
    exit 1
fi

echo ""
echo "============================================"
echo "Phase 3a Complete: Manual CI Validated ✅"
echo "============================================"
echo "Backend: $BACKEND_TYPE"
echo "Image Tag: $IMAGE_TAG"
echo "ECR URI: $ECR_REPO_URI"
echo ""
echo "Next step: Phase 3b - Manual CD Testing"
if [ "$BACKEND_TYPE" == "demo-backend" ]; then
    echo "Run: ./scripts/aws-ci-cd/31-cd-deploy-sam.sh --demo"
else
    echo "Run: ./scripts/aws-ci-cd/31-cd-deploy-sam.sh --prod"
fi
echo "     (Image tag will be auto-detected)"
echo ""
echo "Or specify tag explicitly:"
if [ "$BACKEND_TYPE" == "demo-backend" ]; then
    echo "Run: ./scripts/aws-ci-cd/31-cd-deploy-sam.sh --demo --image-tag $IMAGE_TAG"
else
    echo "Run: ./scripts/aws-ci-cd/31-cd-deploy-sam.sh --prod --image-tag $IMAGE_TAG"
fi
echo ""
