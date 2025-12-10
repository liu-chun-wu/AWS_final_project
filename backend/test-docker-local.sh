#!/bin/bash

##############################################################################
# Docker Local Testing Script
#
# This script tests the Docker container locally before AWS deployment
# It validates that the containerized application works correctly
##############################################################################

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="aws-lab-flask-demo:local"
CONTAINER_NAME="flask-test-container"
PORT=8000
BACKEND_DIR="backend"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Docker Local Testing Script                          ║${NC}"
echo -e "${BLUE}║                                                                ║${NC}"
echo -e "${BLUE}║  Tests the production backend Docker container locally        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"

# Navigate to backend directory
cd "$BACKEND_DIR" || {
    echo -e "${RED}✗ Error: Backend directory not found${NC}"
    exit 1
}

##############################################################################
# Step 1: Check Prerequisites
##############################################################################
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Step 1: Checking Prerequisites${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if Docker is running
echo -e "\n  Checking Docker..."
if docker info > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker is ready${NC}"
else
    echo -e "${RED}✗ Docker is not running${NC}"
    echo -e "${YELLOW}  Please start Docker Desktop and try again${NC}"
    exit 1
fi

# Check if .env file exists
echo -e "  Checking .env file..."
if [ -f ".env" ]; then
    echo -e "${GREEN}✓ .env file found${NC}"
else
    echo -e "${RED}✗ .env file not found${NC}"
    echo -e "${YELLOW}  Please create .env file with required environment variables${NC}"
    exit 1
fi

# Check if Dockerfile exists
echo -e "  Checking Dockerfile..."
if [ -f "Dockerfile" ]; then
    echo -e "${GREEN}✓ Dockerfile found${NC}"
else
    echo -e "${RED}✗ Dockerfile not found${NC}"
    exit 1
fi

##############################################################################
# Step 2: Build Docker Image
##############################################################################
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Step 2: Building Docker Image${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "\n  Building image: ${YELLOW}${IMAGE_NAME}${NC}"
echo -e "  This may take a few minutes on first build...\n"

docker build --platform linux/amd64 --provenance=false --sbom=false -t "$IMAGE_NAME" .

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ Docker build successful${NC}"

    # Show image size
    IMAGE_SIZE=$(docker images "$IMAGE_NAME" --format "{{.Size}}")
    echo -e "  Image size: ${YELLOW}${IMAGE_SIZE}${NC}"
else
    echo -e "\n${RED}✗ Docker build failed${NC}"
    echo -e "${YELLOW}  Check the error messages above${NC}"
    exit 1
fi

##############################################################################
# Step 3: Clean up any existing test container
##############################################################################
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Step 3: Cleaning Up Previous Containers${NC}"
echo -e "${BLUE}========================================${NC}"

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "\n  Removing existing container..."
    docker stop "$CONTAINER_NAME" 2>/dev/null
    docker rm "$CONTAINER_NAME" 2>/dev/null
    echo -e "${GREEN}✓ Cleaned up previous container${NC}"
else
    echo -e "\n  No previous containers to clean up"
fi

##############################################################################
# Step 4: Run Docker Container
##############################################################################
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Step 4: Starting Docker Container${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "\n  Starting container on port ${YELLOW}${PORT}${NC}..."
docker run -d \
    --name "$CONTAINER_NAME" \
    -p ${PORT}:${PORT} \
    --env-file .env \
    "$IMAGE_NAME"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Container started successfully${NC}"
    echo -e "  Container name: ${YELLOW}${CONTAINER_NAME}${NC}"
    echo -e "  Port: ${YELLOW}${PORT}${NC}"
else
    echo -e "${RED}✗ Container failed to start${NC}"
    exit 1
fi

# Wait for container to be ready
echo -e "\n  Waiting for application to be ready..."
sleep 8
echo -e "${GREEN}✓ Application should be ready${NC}"

##############################################################################
# Step 5: Test Endpoints
##############################################################################
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Step 5: Testing API Endpoints${NC}"
echo -e "${BLUE}========================================${NC}"

# Function to test endpoint
test_endpoint() {
    local test_name=$1
    local method=$2
    local endpoint=$3
    local data=$4
    local expected=$5

    echo -e "\n${YELLOW}Test: ${test_name}${NC}"
    echo -e "  Endpoint: ${method} ${endpoint}"

    if [ "$method" == "GET" ]; then
        response=$(curl -s "http://localhost:${PORT}${endpoint}")
    else
        response=$(curl -s -X "$method" "http://localhost:${PORT}${endpoint}" \
            -H "Content-Type: application/json" \
            -d "$data")
    fi

    echo -e "  Response: ${response:0:100}..."

    if echo "$response" | grep -q "$expected"; then
        echo -e "${GREEN}✓ Test passed${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Check response above for details${NC}"
        return 1
    fi
}

# Test 1: Health Check
test_endpoint "Health Check" "GET" "/health" "" "production-backend"

# Test 2: Image Generation (will test endpoint, may fail on expired AWS token)
test_endpoint "Image Generation Endpoint" "POST" "/generate-image" \
    '{"prompt":"a beautiful sunset over mountains","user_id":"docker_test"}' \
    "success"

# Test 3: Audio Generation (will test endpoint)
test_endpoint "Audio Generation Endpoint" "POST" "/generate-audio" \
    '{"prompt":"relaxing piano music","user_id":"docker_test"}' \
    "success"

# Test 4: History
test_endpoint "History Endpoint" "GET" "/history?user_id=docker_test" "" "success"

##############################################################################
# Step 6: Show Container Logs
##############################################################################
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Step 6: Container Logs (Last 20 lines)${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "\n${YELLOW}Recent logs:${NC}"
docker logs --tail 20 "$CONTAINER_NAME"

##############################################################################
# Step 7: Show Container Stats
##############################################################################
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Step 7: Container Statistics${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "\n${YELLOW}Container resource usage:${NC}"
docker stats "$CONTAINER_NAME" --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

##############################################################################
# Interactive Menu
##############################################################################
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Testing Complete${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "\n${YELLOW}Container is still running. What would you like to do?${NC}"
echo -e "  1) Keep container running for manual testing"
echo -e "  2) View live logs (Ctrl+C to exit)"
echo -e "  3) Open interactive shell in container"
echo -e "  4) Stop and remove container"
echo -e "  5) Exit (keep container running)"

read -p "Enter choice [1-5]: " choice

case $choice in
    1)
        echo -e "\n${GREEN}Container is running at http://localhost:${PORT}${NC}"
        echo -e "Container name: ${YELLOW}${CONTAINER_NAME}${NC}"
        echo -e "\nTo view logs: ${YELLOW}docker logs -f ${CONTAINER_NAME}${NC}"
        echo -e "To stop: ${YELLOW}docker stop ${CONTAINER_NAME}${NC}"
        ;;
    2)
        echo -e "\n${YELLOW}Showing live logs (Ctrl+C to exit)...${NC}\n"
        docker logs -f "$CONTAINER_NAME"
        ;;
    3)
        echo -e "\n${YELLOW}Opening shell in container...${NC}\n"
        docker exec -it "$CONTAINER_NAME" /bin/bash
        ;;
    4)
        echo -e "\n${YELLOW}Stopping and removing container...${NC}"
        docker stop "$CONTAINER_NAME"
        docker rm "$CONTAINER_NAME"
        echo -e "${GREEN}✓ Container stopped and removed${NC}"
        ;;
    5)
        echo -e "\n${GREEN}Container is still running at http://localhost:${PORT}${NC}"
        echo -e "To stop: ${YELLOW}docker stop ${CONTAINER_NAME}${NC}"
        ;;
    *)
        echo -e "\n${YELLOW}Invalid choice. Container is still running.${NC}"
        echo -e "To stop: ${YELLOW}docker stop ${CONTAINER_NAME}${NC}"
        ;;
esac

echo -e "\n${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}Docker Testing Script Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}\n"

# Show final instructions
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${YELLOW}Container Status:${NC} Running"
    echo -e "${YELLOW}Access URL:${NC} http://localhost:${PORT}/health"
    echo -e "\n${YELLOW}Quick Commands:${NC}"
    echo -e "  Test health: ${GREEN}curl http://localhost:${PORT}/health${NC}"
    echo -e "  View logs:   ${GREEN}docker logs -f ${CONTAINER_NAME}${NC}"
    echo -e "  Stop:        ${GREEN}docker stop ${CONTAINER_NAME}${NC}"
else
    echo -e "${YELLOW}Container Status:${NC} Stopped"
    echo -e "\n${YELLOW}To run again:${NC} ${GREEN}./test-docker-local.sh${NC}"
fi

echo ""
