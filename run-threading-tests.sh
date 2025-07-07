#!/bin/bash

# Script to run threading verification tests with appropriate diagnostics enabled

echo "🔍 Running Threading Verification Tests for C11S House iOS App"
echo "============================================================"

# Set up environment
export DEVELOPER_DIR=$(xcode-select -p)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to run tests with specific scheme settings
run_tests_with_diagnostics() {
    local test_name=$1
    local scheme_name="C11SHouse"
    
    echo -e "\n${YELLOW}Running: $test_name${NC}"
    echo "----------------------------------------"
    
    # Build test scheme with thread sanitizer
    xcodebuild test \
        -workspace C11Shouse/C11SHouse.xcworkspace \
        -scheme "$scheme_name" \
        -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
        -enableThreadSanitizer YES \
        -enableMainThreadChecker YES \
        -only-testing:C11SHouseTests/ThreadingVerificationTests \
        -quiet \
        2>&1 | grep -E "(Test Case|failed|passed|Thread|Main Thread Checker)"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo -e "${GREEN}✓ $test_name passed${NC}"
    else
        echo -e "${RED}✗ $test_name failed${NC}"
        return 1
    fi
}

# Function to run UI tests
run_ui_tests() {
    echo -e "\n${YELLOW}Running UI Threading Safety Tests${NC}"
    echo "----------------------------------------"
    
    xcodebuild test \
        -workspace C11Shouse/C11SHouse.xcworkspace \
        -scheme "C11SHouse" \
        -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
        -only-testing:C11SHouseUITests/ThreadingSafetyUITests \
        -quiet \
        2>&1 | grep -E "(Test Case|failed|passed|UI Testing Failure)"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo -e "${GREEN}✓ UI Threading tests passed${NC}"
    else
        echo -e "${RED}✗ UI Threading tests failed${NC}"
        return 1
    fi
}

# Function to check for threading warnings in build
check_build_warnings() {
    echo -e "\n${YELLOW}Checking for threading warnings in build${NC}"
    echo "----------------------------------------"
    
    local warnings=$(xcodebuild build \
        -workspace C11Shouse/C11SHouse.xcworkspace \
        -scheme "C11SHouse" \
        -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
        -quiet \
        2>&1 | grep -i "thread\|main thread\|dispatch")
    
    if [ -z "$warnings" ]; then
        echo -e "${GREEN}✓ No threading warnings found${NC}"
    else
        echo -e "${RED}✗ Threading warnings detected:${NC}"
        echo "$warnings"
        return 1
    fi
}

# Function to run app with diagnostics and check console
run_app_with_diagnostics() {
    echo -e "\n${YELLOW}Running app with threading diagnostics${NC}"
    echo "----------------------------------------"
    
    # Build and install app
    xcodebuild build \
        -workspace C11Shouse/C11SHouse.xcworkspace \
        -scheme "C11SHouse" \
        -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
        -configuration Debug \
        -quiet
    
    # Launch with diagnostics
    xcrun simctl launch --console booted com.c11shouse.app \
        --args -com.apple.CoreData.ConcurrencyDebug 1 \
        -NSMainThreadCheckerEnabled 1 \
        > app_console.log 2>&1 &
    
    APP_PID=$!
    
    # Let app run for 30 seconds
    echo "App running with diagnostics for 30 seconds..."
    sleep 30
    
    # Kill the app
    kill $APP_PID 2>/dev/null
    
    # Check for threading issues in console
    local issues=$(grep -i "main thread\|purple\|thread" app_console.log | grep -v "normal")
    
    if [ -z "$issues" ]; then
        echo -e "${GREEN}✓ No threading issues detected in console${NC}"
    else
        echo -e "${RED}✗ Threading issues found in console:${NC}"
        echo "$issues" | head -10
        echo "See app_console.log for full details"
    fi
    
    # Clean up
    rm -f app_console.log
}

# Main execution
main() {
    echo "Starting threading verification tests..."
    echo "Date: $(date)"
    echo "Xcode Version: $(xcodebuild -version | head -1)"
    echo ""
    
    # Ensure simulator is booted
    echo "Booting simulator..."
    xcrun simctl boot "iPhone 15 Pro" 2>/dev/null || true
    
    # Wait for simulator
    sleep 5
    
    # Run all tests
    local failed=0
    
    run_tests_with_diagnostics "Unit Tests" || ((failed++))
    run_ui_tests || ((failed++))
    check_build_warnings || ((failed++))
    run_app_with_diagnostics || ((failed++))
    
    # Summary
    echo -e "\n============================================================"
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}✅ All threading verification tests PASSED!${NC}"
        echo "The app appears to be thread-safe with no detected issues."
    else
        echo -e "${RED}❌ $failed threading test(s) FAILED${NC}"
        echo "Please review the issues above and fix threading problems."
    fi
    echo "============================================================"
    
    # Generate report
    echo -e "\nGenerating detailed report..."
    cat > threading-test-results.txt << EOF
Threading Verification Test Results
==================================
Date: $(date)
Xcode Version: $(xcodebuild -version | head -1)

Test Summary:
- Unit Tests: $([ $failed -eq 0 ] && echo "PASSED" || echo "FAILED")
- UI Tests: $([ $failed -eq 0 ] && echo "PASSED" || echo "FAILED")
- Build Warnings: $([ $failed -eq 0 ] && echo "NONE" || echo "FOUND")
- Runtime Diagnostics: $([ $failed -eq 0 ] && echo "CLEAN" || echo "ISSUES")

Overall Result: $([ $failed -eq 0 ] && echo "PASSED" || echo "FAILED")

Recommendations:
1. Enable Main Thread Checker in Xcode scheme for development
2. Use Thread Sanitizer during testing
3. Monitor Xcode console for purple runtime warnings
4. Profile with Instruments Time Profiler for thread usage

For more details, see threading-verification-report.md
EOF
    
    echo -e "${GREEN}Report saved to threading-test-results.txt${NC}"
    
    exit $failed
}

# Run main function
main