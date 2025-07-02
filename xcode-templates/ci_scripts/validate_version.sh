#!/bin/bash

# Validate version tag matches app version
echo "Validating version..."

# Get version from tag
TAG_VERSION=${CI_TAG#v}

# Get version from Info.plist
APP_VERSION=$(xcrun agvtool what-marketing-version -terse1)

if [ "$TAG_VERSION" != "$APP_VERSION" ]; then
    echo "Error: Tag version ($TAG_VERSION) does not match app version ($APP_VERSION)"
    exit 1
fi

echo "Version validation passed: $APP_VERSION"