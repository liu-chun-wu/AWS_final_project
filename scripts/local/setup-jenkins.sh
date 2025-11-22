#!/bin/bash

################################################################################
# Local Jenkins Setup Script
################################################################################
#
# Purpose: Set up Jenkins container for local CI testing
#
# This script documents and automates the Jenkins setup you already have working.
# It's useful for:
# - Rebuilding Jenkins environment if container is deleted
# - Setting up Jenkins on a new machine
# - Understanding how your local CI works
#
# This creates a LOCAL JENKINS environment for CI testing only (no AWS deployment)
# - Runs on localhost:8080
# - Uses ngrok for webhook tunneling
# - Tests code before merging to production
#
################################################################################

set -e  # Exit on any error

# Color codes for pretty output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
JENKINS_CONTAINER_NAME="jenkins-local"
JENKINS_HTTP_PORT="8080"
JENKINS_AGENT_PORT="50000"
JENKINS_VOLUME="jenkins_home"

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

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "  $1"
}

################################################################################
# Step 1: Check Prerequisites
################################################################################

check_prerequisites() {
    print_header "Step 1: Checking Prerequisites"

    # Check if Docker is installed
    print_info "Checking if Docker is installed..."
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        print_info "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
        exit 1
    fi
    print_success "Docker is installed ($(docker --version))"

    # Check if Docker is running
    print_info "Checking if Docker is running..."
    if ! docker ps &> /dev/null; then
        print_error "Docker is not running"
        print_info "Please start Docker Desktop"
        exit 1
    fi
    print_success "Docker is running"

    echo ""
}

################################################################################
# Step 2: Stop and Remove Existing Jenkins Container
################################################################################

cleanup_existing() {
    print_header "Step 2: Cleaning Up Existing Jenkins"

    # Check if container exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${JENKINS_CONTAINER_NAME}$"; then
        print_info "Found existing Jenkins container: ${JENKINS_CONTAINER_NAME}"

        # Stop if running
        if docker ps --format '{{.Names}}' | grep -q "^${JENKINS_CONTAINER_NAME}$"; then
            print_info "Stopping running container..."
            docker stop ${JENKINS_CONTAINER_NAME}
            print_success "Container stopped"
        fi

        # Remove container
        print_info "Removing container..."
        docker rm ${JENKINS_CONTAINER_NAME}
        print_success "Container removed"

        print_warning "Note: Jenkins volume '${JENKINS_VOLUME}' is preserved (keeps your configuration)"
    else
        print_info "No existing Jenkins container found"
    fi

    echo ""
}

################################################################################
# Step 3: Start Jenkins Container
################################################################################

start_jenkins() {
    print_header "Step 3: Starting Jenkins Container"

    print_info "This creates a Jenkins container with:"
    print_info "  - HTTP port: ${JENKINS_HTTP_PORT} (web interface)"
    print_info "  - Agent port: ${JENKINS_AGENT_PORT} (build agents)"
    print_info "  - Volume: ${JENKINS_VOLUME} (persistent data)"
    print_info "  - Docker socket: mounted (to build images)"
    echo ""

    print_info "Starting Jenkins..."
    docker run -d \
        --name ${JENKINS_CONTAINER_NAME} \
        -p ${JENKINS_HTTP_PORT}:8080 \
        -p ${JENKINS_AGENT_PORT}:50000 \
        -v ${JENKINS_VOLUME}:/var/jenkins_home \
        -v /var/run/docker.sock:/var/run/docker.sock \
        jenkins/jenkins:lts

    print_success "Jenkins container started"

    print_info "Waiting for Jenkins to start (this takes ~30 seconds)..."
    sleep 30

    echo ""
}

################################################################################
# Step 4: Install Tools in Jenkins Container
################################################################################

install_tools() {
    print_header "Step 4: Installing Required Tools"

    print_info "Jenkins needs Python and Docker CLI to run your pipeline:"
    print_info "  - Python 3: To run your Flask app and tests"
    print_info "  - Docker CLI: To build Docker images"
    echo ""

    # Install Python 3
    print_info "Installing Python 3 and related tools..."
    docker exec -u root ${JENKINS_CONTAINER_NAME} bash -c '
        apt-get update -qq && \
        apt-get install -y -qq python3 python3-pip python3-venv python3-dev build-essential > /dev/null 2>&1
    '
    PYTHON_VERSION=$(docker exec -u root ${JENKINS_CONTAINER_NAME} python3 --version)
    print_success "Python installed: ${PYTHON_VERSION}"

    # Install Docker CLI
    print_info "Installing Docker CLI..."
    docker exec -u root ${JENKINS_CONTAINER_NAME} bash -c '
        apt-get update -qq && \
        apt-get install -y -qq ca-certificates curl gnupg lsb-release > /dev/null 2>&1 && \
        install -m 0755 -d /etc/apt/keyrings && \
        curl -fsSL https://download.docker.com/linux/debian/gpg | \
          gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null && \
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
          https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null && \
        apt-get update -qq && \
        apt-get install -y -qq docker-ce-cli > /dev/null 2>&1
    '
    DOCKER_VERSION=$(docker exec -u root ${JENKINS_CONTAINER_NAME} docker --version)
    print_success "Docker CLI installed: ${DOCKER_VERSION}"

    # Fix Docker socket permissions
    print_info "Configuring Docker socket permissions..."
    docker exec -u root ${JENKINS_CONTAINER_NAME} chmod 666 /var/run/docker.sock
    print_success "Docker socket permissions configured"

    echo ""
}

################################################################################
# Step 5: Display Access Information
################################################################################

display_info() {
    print_header "Step 5: Jenkins Access Information"

    # Get initial admin password
    print_info "Retrieving initial admin password..."
    ADMIN_PASSWORD=$(docker exec ${JENKINS_CONTAINER_NAME} cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "Already configured")

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                  JENKINS IS READY!                             ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BLUE}Jenkins URL:${NC}           http://localhost:${JENKINS_HTTP_PORT}"
    echo -e "  ${BLUE}Blue Ocean URL:${NC}        http://localhost:${JENKINS_HTTP_PORT}/blue"
    echo -e "  ${BLUE}Initial Admin Password:${NC} ${ADMIN_PASSWORD}"
    echo ""

    if [ "$ADMIN_PASSWORD" != "Already configured" ]; then
        print_info "First-time setup:"
        print_info "  1. Open http://localhost:8080 in your browser"
        print_info "  2. Enter the admin password above"
        print_info "  3. Install suggested plugins"
        print_info "  4. Create admin user"
        print_info "  5. Install Blue Ocean plugin"
        print_info "  6. Create pipeline from GitHub"
        echo ""
        print_info "For detailed setup instructions, see: JENKINS_BLUE_OCEAN_SETUP.md"
    else
        print_info "Jenkins is already configured"
        print_info "Open Blue Ocean at: http://localhost:8080/blue"
    fi

    echo ""
    print_header "Next Steps"

    print_info "To test local CI pipeline:"
    print_info "  1. Make code changes"
    print_info "  2. Run: ./scripts/local/test-local.sh     # Test locally"
    print_info "  3. Run: ./scripts/local/build-local.sh    # Build locally"
    print_info "  4. Push to Jeffery branch                 # Trigger Jenkins"
    echo ""

    print_info "To set up GitHub webhook (for automatic builds):"
    print_info "  1. Start ngrok: ngrok http 8080"
    print_info "  2. Configure GitHub webhook with ngrok URL"
    print_info "  3. See JENKINS_BLUE_OCEAN_SETUP.md for details"
    echo ""

    print_info "To view Jenkins logs:"
    print_info "  docker logs -f ${JENKINS_CONTAINER_NAME}"
    echo ""

    print_info "To stop Jenkins:"
    print_info "  docker stop ${JENKINS_CONTAINER_NAME}"
    echo ""

    print_info "To restart Jenkins:"
    print_info "  docker start ${JENKINS_CONTAINER_NAME}"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║            LOCAL JENKINS CI SETUP SCRIPT                       ║${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}║  This script sets up Jenkins for local CI testing             ║${NC}"
    echo -e "${BLUE}║  (CI only - no AWS deployment)                                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    check_prerequisites
    cleanup_existing
    start_jenkins
    install_tools
    display_info

    print_success "Setup complete! Jenkins is running at http://localhost:${JENKINS_HTTP_PORT}"
    echo ""
}

# Run main function
main "$@"
