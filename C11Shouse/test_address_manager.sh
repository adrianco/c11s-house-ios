#!/bin/bash

# Test script to run AddressManager tests
echo "Running AddressManager tests..."

# Try to run the specific test
if command -v swift &> /dev/null; then
    echo "Running with swift test..."
    swift test --filter AddressManagerTests.testFullAddressFlowIntegration
elif command -v xcodebuild &> /dev/null; then
    echo "Running with xcodebuild..."
    xcodebuild test -scheme C11SHouse -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:C11SHouseTests/AddressManagerTests/testFullAddressFlowIntegration
else
    echo "Neither swift nor xcodebuild available in this environment"
    echo "Please run the test manually in Xcode or a Swift environment"
fi