#!/bin/bash
# Script: 30-cd-validate-sam.sh
# Purpose: Validate SAM template before deployment
# Usage: ./30-cd-validate-sam.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

AWS_REGION="${AWS_REGION:-us-east-1}"
REPO_NAME="aws-lab-flask-demo"

echo "============================================"
echo "Phase 3b: SAM Template Validation"
echo "============================================"
echo "Region: $AWS_REGION"
echo ""

cd "$PROJECT_ROOT"

# Step 1: Validate SAM template syntax
echo "Step 1: Validating SAM template syntax..."
if [ -f "aws/template.yaml" ]; then
    sam validate --template aws/template.yaml
    if [ $? -eq 0 ]; then
        echo "✅ SAM template syntax is valid"
    else
        echo "❌ SAM template validation failed"
        exit 1
    fi
else
    echo "❌ SAM template not found at aws/template.yaml"
    exit 1
fi

echo ""

# Step 2: Check ECR repository exists
echo "Step 2: Checking ECR repository..."
ECR_REPO_URI=$(aws ecr describe-repositories \
    --repository-names "$REPO_NAME" \
    --region "$AWS_REGION" \
    --query 'repositories[0].repositoryUri' \
    --output text 2>/dev/null)

if [ -z "$ECR_REPO_URI" ]; then
    echo "❌ ECR repository not found"
    exit 1
fi

echo "✅ ECR repository exists: $ECR_REPO_URI"
echo ""

# Step 3: Check if at least one image exists in ECR
echo "Step 3: Checking for images in ECR..."
IMAGE_COUNT=$(aws ecr list-images \
    --repository-name "$REPO_NAME" \
    --region "$AWS_REGION" \
    --query 'length(imageIds)' \
    --output text 2>/dev/null)

if [ "$IMAGE_COUNT" -gt 0 ]; then
    echo "✅ Found $IMAGE_COUNT image(s) in ECR"

    echo ""
    echo "Available images:"
    aws ecr describe-images \
        --repository-name "$REPO_NAME" \
        --region "$AWS_REGION" \
        --query 'sort_by(imageDetails,&imagePushedAt)[-5:].{Tag:imageTags[0],Pushed:imagePushedAt,Size:imageSizeInBytes}' \
        --output table
else
    echo "⚠️  No images in ECR yet. Run 20-ci-build-and-push.sh first"
fi

echo ""

# Step 4: Check LabRole exists
echo "Step 4: Checking for LabRole..."
ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text 2>/dev/null)

if [ -n "$ROLE_ARN" ]; then
    echo "✅ LabRole exists: $ROLE_ARN"
else
    echo "❌ LabRole not found (required for AWS Learner Lab)"
    exit 1
fi

echo ""

# Step 5: Test SAM build
echo "Step 5: Testing SAM build..."
sam build --use-container --template aws/template.yaml

if [ $? -eq 0 ]; then
    echo "✅ SAM build successful"
else
    echo "❌ SAM build failed"
    exit 1
fi

echo ""
echo "============================================"
echo "SAM Validation Complete ✅"
echo "============================================"
echo "Template: aws/template.yaml"
echo "ECR Repository: $ECR_REPO_URI"
echo "LabRole: $ROLE_ARN"
echo ""
echo "Next step: Deploy SAM"
echo "Run: ./scripts/aws-ci-cd/31-cd-deploy-sam.sh [--demo|--prod] --image-tag <tag>"
echo ""
