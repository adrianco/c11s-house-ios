#!/bin/bash

echo "C11S House Xcode Project Setup"
echo "=============================="
echo ""
echo "This script will help you set up the Xcode project with pre-configured files."
echo ""

# Check if Xcode project exists
if [ ! -d "C11SHouse.xcodeproj" ]; then
    echo "ERROR: C11SHouse.xcodeproj not found!"
    echo ""
    echo "Please follow these steps:"
    echo "1. Open Xcode"
    echo "2. Create a new iOS App project named 'C11SHouse'"
    echo "3. Save it in this directory (/workspaces/c11s-house-ios/)"
    echo "4. Close Xcode"
    echo "5. Run this script again"
    exit 1
fi

echo "Found Xcode project. Integrating pre-configured files..."

# Backup original files
echo "Creating backups..."
mkdir -p .backup
cp -r C11SHouse C11SHouseTests C11SHouseUITests .backup/ 2>/dev/null || true

# Copy source files
echo "Copying source files..."
cp xcode-templates/C11SHouse/*.swift C11SHouse/ 2>/dev/null || echo "Source files already in place"

# Copy test files
echo "Copying test files..."
cp xcode-templates/C11SHouseTests/*.swift C11SHouseTests/ 2>/dev/null || echo "Test files already in place"
cp xcode-templates/C11SHouseUITests/*.swift C11SHouseUITests/ 2>/dev/null || echo "UI test files already in place"

# Copy Xcode Cloud workflows
echo "Setting up Xcode Cloud workflows..."
if [ -d "xcode-templates/.xcode" ]; then
    cp -r xcode-templates/.xcode .
    echo "✓ Xcode Cloud workflows copied"
else
    echo "✓ Xcode Cloud workflows already in place"
fi

# Copy CI scripts
echo "Setting up CI scripts..."
if [ -d "xcode-templates/ci_scripts" ]; then
    cp -r xcode-templates/ci_scripts .
    echo "✓ CI scripts copied"
else
    echo "✓ CI scripts already in place"
fi

# Copy Assets if needed
if [ -d "xcode-templates/C11SHouse/Assets.xcassets" ] && [ -d "C11SHouse" ]; then
    echo "Copying asset catalogs..."
    cp -r xcode-templates/C11SHouse/Assets.xcassets C11SHouse/
    echo "✓ Asset catalogs copied"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Open C11SHouse.xcodeproj in Xcode"
echo "2. Verify the bundle identifier is set to: com.c11s.house"
echo "3. Configure your development team"
echo "4. Follow the Xcode Cloud setup in XCODE_CLOUD_SETUP.md"
echo ""

# Create .gitignore if it doesn't exist
if [ ! -f ".gitignore" ]; then
    echo "Creating .gitignore..."
    cat > .gitignore << 'EOF'
# Xcode
#
# gitignore contributors: remember to update Global/Xcode.gitignore, Objective-C.gitignore & Swift.gitignore

## User settings
xcuserdata/

## compatibility with Xcode 8 and earlier (ignoring not required starting Xcode 9)
*.xcscmblueprint
*.xccheckout

## compatibility with Xcode 3 and earlier (ignoring not required starting Xcode 4)
build/
DerivedData/
*.moved-aside
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3

## Gcc Patch
/*.gcno

# Swift Package Manager
.build/
.swiftpm/

# CocoaPods
Pods/

# Carthage
Carthage/Build/

# Backup files
.backup/

# macOS
.DS_Store
EOF
    echo "✓ .gitignore created"
fi