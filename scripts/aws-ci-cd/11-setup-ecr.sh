#!/bin/bash
# Script: 11-setup-ecr.sh
# Purpose: Setup Amazon ECR repository for Flask demo
# Usage: ./11-setup-ecr.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_NAME="aws-lab-flask-demo"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "============================================"
echo "ECR Repository Setup"
echo "============================================"
echo "Repository: $REPO_NAME"
echo "Region: $AWS_REGION"
echo ""

# Check if repository already exists
echo "Checking if ECR repository exists..."
if aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$AWS_REGION" &>/dev/null; then
    echo "✅ Repository '$REPO_NAME' already exists"

    # Get repository URI
    REPO_URI=$(aws ecr describe-repositories \
        --repository-names "$REPO_NAME" \
        --region "$AWS_REGION" \
        --query 'repositories[0].repositoryUri' \
        --output text)

    echo "Repository URI: $REPO_URI"
else
    echo "Creating ECR repository..."

    # Create repository
    REPO_URI=$(aws ecr create-repository \
        --repository-name "$REPO_NAME" \
        --region "$AWS_REGION" \
        --image-scanning-configuration scanOnPush=true \
        --query 'repository.repositoryUri' \
        --output text)

    if [ $? -eq 0 ]; then
        echo "✅ Repository created successfully"
        echo "Repository URI: $REPO_URI"
    else
        echo "❌ Failed to create repository"
        exit 1
    fi
fi

echo ""
echo "============================================"
echo "ECR Repository Ready"
echo "============================================"
echo "Repository Name: $REPO_NAME"
echo "Repository URI: $REPO_URI"
echo "Region: $AWS_REGION"
echo ""
echo "Next steps:"
echo "1. Build Docker image: docker build -t aws-lab-flask-demo:latest backend/"
echo "2. Tag for ECR: docker tag aws-lab-flask-demo:latest $REPO_URI:latest"
echo "3. Login to ECR: aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REPO_URI"
echo "4. Push to ECR: docker push $REPO_URI:latest"
echo ""

# Save repository URI to file for other scripts
echo "$REPO_URI" > "$SCRIPT_DIR/.ecr-repo-uri"
echo "Repository URI saved to: $SCRIPT_DIR/.ecr-repo-uri"
