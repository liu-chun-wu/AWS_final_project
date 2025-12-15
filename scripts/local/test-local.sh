#!/bin/bash

################################################################################
# Local Test Script
################################################################################
#
# Purpose: Run pytest tests locally (without Jenkins)
#
# This script:
# - Runs your complete test suite (unit + integration tests)
# - Same tests that Jenkins runs in Stage 5
# - Fast feedback without waiting for Jenkins
#
# Use this when you want to:
# - Test changes before committing
# - Debug failing tests locally
# - Run tests without triggering Jenkins pipeline
#
################################################################################

set -e  # Exit on any error

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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
            echo "  --demo    Test demo-backend (Flask validation demo)"
            echo "  --prod    Test backend (production service)"
            echo ""
            echo "You MUST specify either --demo or --prod."
            echo ""
            echo "Examples:"
            echo "  $0 --demo   # Test demo backend"
            echo "  $0 --prod   # Test production backend"
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
    echo -e "${YELLOW}You must specify which backend to test:${NC}"
    echo ""
    echo "  $0 --demo   # Test demo backend"
    echo "  $0 --prod   # Test production backend"
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
    echo "  $0 --demo   # Test demo backend"
    echo "  $0 --prod   # Test production backend"
    exit 1
fi

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ "$USE_DEMO" = true ]; then
    BACKEND_DIR="${PROJECT_ROOT}/demo-backend"
    BACKEND_NAME="demo-backend"
elif [ "$USE_PROD" = true ]; then
    BACKEND_DIR="${PROJECT_ROOT}/backend"
    BACKEND_NAME="backend"
else
    # This should never happen due to validation above
    echo "FATAL ERROR: Invalid backend state"
    exit 1
fi

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

################################################################################
# Step 1: Check Prerequisites
################################################################################

check_prerequisites() {
print_header "Step 1: Checking Prerequisites"

# Pick Python interpreter (prefer 3.11 to match Lambda/runtime wheels)
if command -v python3.11 >/dev/null 2>&1; then
    PY_BIN="python3.11"
else
    PY_BIN="python3"
fi

print_info "Using Python interpreter: $PY_BIN"
if ! command -v "$PY_BIN" &> /dev/null; then
    print_error "Required Python interpreter not found: $PY_BIN"
    exit 1
fi
PYTHON_VERSION=$($PY_BIN --version)
print_success "Python found: ${PYTHON_VERSION}"

    # Check if backend directory exists
    print_info "Checking backend directory..."
    if [ ! -d "${BACKEND_DIR}" ]; then
        print_error "Backend directory not found at ${BACKEND_DIR}"
        exit 1
    fi
    print_success "Backend directory found"

    # Check if tests exist
    print_info "Checking tests..."
    if [ ! -d "${BACKEND_DIR}/tests" ]; then
        print_error "Tests directory not found at ${BACKEND_DIR}/tests"
        exit 1
    fi
    print_success "Tests directory found"

    echo ""
}

################################################################################
# Step 2: Set Up Python Environment
################################################################################

setup_environment() {
    print_header "Step 2: Setting Up Python Environment"

    cd "${BACKEND_DIR}"

    # (Re)create venv if missing or Python interpreter changed
    CURRENT_INTERP=""
    if [ -x ".venv/bin/python" ]; then
        CURRENT_INTERP=$(.venv/bin/python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    fi

    DESIRED_INTERP=$($PY_BIN -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')

    if [ ! -d ".venv" ] || [ "$CURRENT_INTERP" != "$DESIRED_INTERP" ]; then
        print_info "Creating fresh virtual environment with $PY_BIN (was: ${CURRENT_INTERP:-none})..."
        rm -rf .venv
        "$PY_BIN" -m venv .venv
    else
        print_info "Using existing virtual environment (Python $CURRENT_INTERP)"
    fi

    print_info "Activating virtual environment..."
    source .venv/bin/activate
    print_success "Virtual environment activated"

    print_info "Ensuring dependencies are installed/up-to-date..."
    pip install -q --upgrade pip
    pip install -q -r requirements.txt
    print_success "Dependencies installed"

    echo ""
}

################################################################################
# Step 3: Run Tests
################################################################################

run_tests() {
    print_header "Step 3: Running Tests"

    cd "${BACKEND_DIR}"

    print_info "Test suite includes:"
    print_info "  - Unit tests: ${BACKEND_NAME}/tests/unit/"
    print_info "  - Integration tests: ${BACKEND_NAME}/tests/integration/"
    echo ""

    print_info "Running pytest..."
    echo ""

    # Run pytest with verbose output
    if pytest tests/ -v --tb=short; then
        echo ""
        print_success "All tests passed! ✨"
        TEST_RESULT=0
    else
        echo ""
        print_error "Some tests failed"
        print_info "Fix the failing tests before committing"
        TEST_RESULT=1
    fi

    echo ""
    return $TEST_RESULT
}

################################################################################
# Step 4: Display Summary
################################################################################

display_summary() {
    print_header "Test Summary"

    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                  ALL TESTS PASSED! ✓                           ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        print_info "Your code is ready to:"
        print_info "  1. Commit to Git"
        print_info "  2. Push to Jeffery branch (triggers Jenkins CI)"
        print_info "  3. Build Docker image locally: ./scripts/local/build-local.sh"
        echo ""

    else
        echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                  TESTS FAILED! ✗                               ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        print_info "Next steps:"
        print_info "  1. Review the test failures above"
        print_info "  2. Fix the issues in your code"
        print_info "  3. Run this script again"
        echo ""

        print_info "To run specific tests:"
        echo -e "  ${BLUE}pytest tests/unit/test_health.py -v${NC}           # Run health tests"
        echo -e "  ${BLUE}pytest tests/integration/test_echo.py -v${NC}      # Run echo tests"
        echo -e "  ${BLUE}pytest tests/unit/test_health.py::test_health_endpoint_returns_200 -v${NC}  # Run single test"
        echo ""
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                LOCAL TEST RUNNER                               ║${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}║  Runs pytest test suite locally (same as Jenkins)             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Testing: ${BACKEND_NAME}${NC}"
    echo ""

    check_prerequisites
    setup_environment

    # Run tests and capture exit code
    run_tests
    TEST_EXIT_CODE=$?

    display_summary $TEST_EXIT_CODE

    # Return test exit code
    exit $TEST_EXIT_CODE
}

# Run main function
main "$@"
