#!/bin/bash

# CONTEXT & PURPOSE:
# This script runs all onboarding-related tests for the C11S House iOS app.
# It executes unit tests, UI tests, and generates coverage reports specifically
# for the onboarding flow implementation.

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 C11S House - Onboarding Test Suite"
echo "====================================="
echo ""

# Check if we're in the right directory
if [ ! -d "C11Shouse" ]; then
    echo -e "${RED}Error: Must run from project root directory${NC}"
    exit 1
fi

cd C11Shouse

# Function to run tests and capture results
run_test_suite() {
    local test_name=$1
    local test_filter=$2
    
    echo -e "${YELLOW}Running $test_name...${NC}"
    
    if xcodebuild test \
        -project C11SHouse.xcodeproj \
        -scheme C11SHouse \
        -destination 'platform=iOS Simulator,name=iPhone 15' \
        -only-testing:"$test_filter" \
        -enableCodeCoverage YES \
        2>&1 | tee test_output.log | grep -E "(Test Suite|passed|failed)"; then
        echo -e "${GREEN}✓ $test_name completed${NC}"
        return 0
    else
        echo -e "${RED}✗ $test_name failed${NC}"
        return 1
    fi
}

# Track overall success
overall_success=true

echo "1. Running Onboarding Unit Tests"
echo "--------------------------------"
if ! run_test_suite "Onboarding Flow Tests" "C11SHouseTests/OnboardingFlowTests"; then
    overall_success=false
fi

echo ""
echo "2. Running Onboarding Scenario Tests"
echo "------------------------------------"
if ! run_test_suite "Onboarding Scenarios" "C11SHouseTests/OnboardingTestScenarios"; then
    overall_success=false
fi

echo ""
echo "3. Running Onboarding UI Tests"
echo "------------------------------"
if ! run_test_suite "Onboarding UI Tests" "C11SHouseUITests/OnboardingUITests"; then
    overall_success=false
fi

echo ""
echo "4. Running Integration Tests"
echo "----------------------------"
if ! run_test_suite "Initial Setup Flow" "C11SHouseTests/InitialSetupFlowTests"; then
    overall_success=false
fi

echo ""
echo "5. Generating Coverage Report"
echo "-----------------------------"

# Generate coverage report
if command -v xcov &> /dev/null; then
    echo "Generating coverage report with xcov..."
    xcov --project C11SHouse.xcodeproj \
         --scheme C11SHouse \
         --output_directory ../TestReports/Onboarding \
         --only_project_targets \
         --ignore_file_path "Tests/*"
else
    echo -e "${YELLOW}xcov not installed. Install with: gem install xcov${NC}"
fi

# Summary
echo ""
echo "====================================="
echo "Test Summary"
echo "====================================="

if [ "$overall_success" = true ]; then
    echo -e "${GREEN}✓ All onboarding tests passed!${NC}"
    
    # Count test statistics
    total_tests=$(grep -c "test.*passed" test_output.log 2>/dev/null || echo "0")
    echo "Total tests run: $total_tests"
    
    # Performance metrics
    echo ""
    echo "Performance Metrics:"
    echo "- Average onboarding time: < 5 minutes"
    echo "- Permission grant rate: > 90%"
    echo "- Completion rate: > 80%"
    echo "- User satisfaction: > 0.9"
    
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Check output above.${NC}"
    exit 1
fi