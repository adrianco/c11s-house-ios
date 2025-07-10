#!/bin/bash

# Script to run NotesService tests
# This script helps run the critical NotesService tests from the command line

echo "🧪 Running NotesService Tests - The Central Memory System Tests"
echo "============================================================"
echo ""
echo "These tests validate:"
echo "✓ All CRUD operations (saveOrUpdateNote, getNote, deleteNote)"
echo "✓ Thread safety with concurrent operations"
echo "✓ Data persistence and loading"
echo "✓ Error handling for all failure modes"
echo "✓ House name saving functionality"
echo "✓ Weather summary persistence"
echo "✓ Migration from old data formats"
echo ""

# Navigate to project directory
cd /workspaces/c11s-house-ios/C11Shouse

# Run tests with xcodebuild
echo "Running tests..."
xcodebuild test \
    -project C11SHouse.xcodeproj \
    -scheme C11SHouse \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
    -only-testing:C11SHouseTests/NotesServiceTests \
    | xcpretty --color --test

# Alternative: Run all service tests
# xcodebuild test \
#     -project C11SHouse.xcodeproj \
#     -scheme C11SHouse \
#     -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
#     -only-testing:C11SHouseTests/Services \
#     | xcpretty --color --test

echo ""
echo "✅ Test run complete!"
echo ""
echo "Note: If tests fail, check that:"
echo "1. NotesService properly isolates UserDefaults in tests"
echo "2. Async/await patterns are correctly implemented"
echo "3. Thread safety is maintained for concurrent operations"
echo "4. All error cases are properly handled"