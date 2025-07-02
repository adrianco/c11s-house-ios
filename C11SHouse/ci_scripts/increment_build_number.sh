#!/bin/bash

# Increment build number for beta releases
echo "Incrementing build number..."

# Get current build number
CURRENT_BUILD=$(xcrun agvtool what-version -terse)

# Increment build number
NEW_BUILD=$((CURRENT_BUILD + 1))

# Set new build number
xcrun agvtool new-version -all $NEW_BUILD

echo "Build number incremented from $CURRENT_BUILD to $NEW_BUILD"