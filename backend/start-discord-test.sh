#!/bin/bash

################################################################################
# Discord Bot Testing Startup Script
################################################################################
#
# Purpose: Automatically start backend container and Discord bot for testing
#
# This script:
# 1. Starts the Flask backend in Docker
# 2. Waits for backend to be ready
# 3. Starts the Discord bot
# 4. Handles cleanup on exit
#
# Usage:
#   bash start-discord-test.sh
#
# To stop:
#   Press Ctrl+C (will clean up automatically)
#
################################################################################

set -e  # Exit on error

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${BACKEND_DIR}/.." && pwd)"
CONTAINER_NAME="flask-test-container"
BACKEND_PORT="8000"
IMAGE_NAME="aws-lab-flask-demo:local"
ENV_FILE="${BACKEND_DIR}/.env"

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

print_info() {
    echo -e "  $1"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

################################################################################
# Cleanup Function
################################################################################

cleanup() {
    echo ""
    print_header "Cleaning Up"

    print_info "Stopping Discord bot..."
    # Discord bot will be stopped by Ctrl+C

    print_info "Stopping backend container..."
    docker stop ${CONTAINER_NAME} 2>/dev/null || true

    print_success "Cleanup complete!"
    echo ""
    exit 0
}

# Register cleanup function to run on Ctrl+C
trap cleanup SIGINT SIGTERM

################################################################################
# Main Script
################################################################################

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           DISCORD BOT TESTING STARTUP SCRIPT                   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Step 1: Check Prerequisites
    print_header "Step 1: Checking Prerequisites"

    # Check Docker
    print_info "Checking Docker..."
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi

    if ! docker ps &> /dev/null; then
        print_error "Docker is not running. Please start Docker Desktop."
        exit 1
    fi
    print_success "Docker is ready"

    # Check Python
    print_info "Checking Python..."
    if ! command -v python &> /dev/null && ! command -v python3 &> /dev/null; then
        print_error "Python is not installed"
        exit 1
    fi
    print_success "Python is ready"

    # Check .env file
    print_info "Checking .env file..."
    if [ ! -f "${ENV_FILE}" ]; then
        print_error ".env file not found at ${ENV_FILE}"
        exit 1
    fi
    print_success ".env file found"

    # Check Discord bot script
    print_info "Checking Discord bot script..."
    if [ ! -f "${BACKEND_DIR}/test-discord-bot.py" ]; then
        print_error "test-discord-bot.py not found"
        exit 1
    fi
    print_success "Discord bot script found"

    echo ""

    # Step 2: Start Backend Container
    print_header "Step 2: Starting Backend Container"

    # Check if container already exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_warning "Container '${CONTAINER_NAME}' already exists"
        print_info "Removing old container..."
        docker stop ${CONTAINER_NAME} 2>/dev/null || true
        docker rm ${CONTAINER_NAME} 2>/dev/null || true
    fi

    print_info "Starting container '${CONTAINER_NAME}'..."
    docker run -d \
        --name ${CONTAINER_NAME} \
        -p ${BACKEND_PORT}:${BACKEND_PORT} \
        --env-file "${ENV_FILE}" \
        ${IMAGE_NAME}

    print_success "Container started"
    echo ""

    # Step 3: Wait for Backend to be Ready
    print_header "Step 3: Waiting for Backend"

    print_info "Checking backend health..."
    MAX_RETRIES=10
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if curl -s http://localhost:${BACKEND_PORT}/health > /dev/null 2>&1; then
            print_success "Backend is ready!"

            # Show health response
            HEALTH_RESPONSE=$(curl -s http://localhost:${BACKEND_PORT}/health)
            echo "  Response: ${HEALTH_RESPONSE}"
            break
        fi

        RETRY_COUNT=$((RETRY_COUNT + 1))
        print_info "Waiting... (${RETRY_COUNT}/${MAX_RETRIES})"
        sleep 2
    done

    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        print_error "Backend failed to start"
        print_info "Check logs: docker logs ${CONTAINER_NAME}"
        cleanup
        exit 1
    fi

    echo ""

    # Step 4: Start Discord Bot
    print_header "Step 4: Starting Discord Bot"

    print_info "Starting Discord bot..."
    echo ""
    echo -e "${YELLOW}──────────────────────────────────────────────────────────────${NC}"
    echo -e "${YELLOW}Discord Bot Output (Press Ctrl+C to stop everything):${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────────────────────────${NC}"
    echo ""

    cd "${BACKEND_DIR}"

    # Check which Python has discord.py installed
    if python -c "import discord" &> /dev/null; then
        print_info "Using: $(python --version)"
        python test-discord-bot.py
    elif python3 -c "import discord" &> /dev/null; then
        print_info "Using: $(python3 --version)"
        python3 test-discord-bot.py
    else
        print_error "discord.py not found in any Python installation"
        print_info "Install with: pip install discord.py aiohttp"
        cleanup
        exit 1
    fi
}

# Run main function
main "$@"
