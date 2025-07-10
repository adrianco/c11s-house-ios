# Xcode Cloud Setup Guide for C11S House

## Prerequisites
- Apple Developer Account (Individual or Organization)
- Xcode 15.0 or later
- Admin access to your Apple Developer account
- GitHub account connected to Xcode

## Step 1: Create the Xcode Project

1. Open Xcode
2. Select "Create New Project"
3. Choose "iOS" → "App"
4. Configure the project:
   - Product Name: `C11SHouse`
   - Team: Select your Apple Developer team
   - Organization Identifier: Use your reverse domain (e.g., `com.yourcompany`)
   - Bundle Identifier: Change to `com.c11s.house`
   - Interface: SwiftUI
   - Language: Swift
   - Use Core Data: No
   - Include Tests: Yes
5. Save the project in the `/workspaces/c11s-house-ios/` directory
6. Close Xcode temporarily

## Step 2: Integrate the Pre-configured Files

1. In Terminal, navigate to the project directory:
   ```bash
   cd /workspaces/c11s-house-ios/
   ```

2. Copy the pre-configured files into your new Xcode project:
   ```bash
   # Copy source files
   cp C11SHouse/C11SHouse/*.swift C11SHouse/
   
   # Copy test files
   cp C11SHouse/C11SHouseTests/*.swift C11SHouseTests/
   cp C11SHouse/C11SHouseUITests/*.swift C11SHouseUITests/
   
   # Copy Xcode Cloud workflows
   cp -r C11SHouse/.xcode .
   
   # Copy CI scripts
   cp -r C11SHouse/ci_scripts .
   ```

3. Clean up the template directory:
   ```bash
   rm -rf C11SHouse/C11SHouse
   rm -rf C11SHouse/C11SHouseTests
   rm -rf C11SHouse/C11SHouseUITests
   rm -rf C11SHouse/.xcode
   rm -rf C11SHouse/ci_scripts
   rm C11SHouse/Package.swift
   rm C11SHouse/README.md
   ```

4. Reopen the project in Xcode

## Step 3: Configure Project Settings

1. Select the project in the navigator
2. Under "Signing & Capabilities":
   - Enable "Automatically manage signing"
   - Select your Team from the dropdown
   - Bundle Identifier should be: `com.c11s.house`

## Step 4: Enable Xcode Cloud

1. In Xcode, go to Product → Xcode Cloud → Create Workflow
2. Select your source control provider (GitHub)
3. Grant Xcode Cloud access to your repository
4. Choose the repository containing this project

## Step 5: Configure Environment Groups

Create the following environment groups in Xcode Cloud settings:

### C11S_HOUSE_ENV
- `TEAM_ID`: Your Apple Developer Team ID
- `BUNDLE_IDENTIFIER`: com.c11s.house

### TESTFLIGHT_CREDENTIALS  
- `APP_STORE_CONNECT_API_KEY_ID`: Your API Key ID
- `APP_STORE_CONNECT_ISSUER_ID`: Your Issuer ID
- `APP_STORE_CONNECT_API_KEY`: Your private key (base64 encoded)

### APP_STORE_CREDENTIALS
- Same as TESTFLIGHT_CREDENTIALS

## Step 6: Create App Store Connect API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to Users and Access → Keys
3. Click the + button to create a new key
4. Name it "Xcode Cloud CI"
5. Select appropriate permissions (Admin recommended)
6. Download the key file (.p8)
7. Note the Key ID and Issuer ID

## Step 7: Configure Workflows

The project includes three pre-configured workflows:

1. **CI Build and Test** (`ci.yml`)
   - Triggers on pull requests and pushes to main
   - Builds, tests, and analyzes the code

2. **Beta Release** (`beta.yml`)
   - Triggers on pushes to beta or release branches
   - Uploads to TestFlight automatically

3. **Production Release** (`release.yml`)
   - Triggers on version tags (e.g., v1.0.0)
   - Prepares for App Store submission

## Step 8: Create Your First Build

1. In Xcode Cloud, click "Start Build"
2. Select the "CI Build and Test" workflow
3. Choose the main branch
4. Click "Start Build"

## Step 9: Monitor Build Progress

1. View build progress in Xcode's Report Navigator
2. Check build logs for any issues
3. Download artifacts when build completes

## Troubleshooting

### Common Issues

1. **Signing errors**: Ensure your provisioning profiles are up to date
2. **API key errors**: Verify environment variables are set correctly
3. **Build failures**: Check the build logs in Xcode Cloud

### Useful Commands

```bash
# Check current version
xcrun agvtool what-version -terse

# Check marketing version
xcrun agvtool what-marketing-version -terse1

# Manually increment build number
xcrun agvtool new-version -all <new_number>
```

## Next Steps

1. Create test groups in TestFlight
2. Set up push notification certificates if needed
3. Configure additional environment variables
4. Customize workflows for your team's needs

## Resources

- [Xcode Cloud Documentation](https://developer.apple.com/documentation/xcode/xcode-cloud)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
- [Configuring Xcode Cloud Workflows](https://developer.apple.com/documentation/xcode/configuring-xcode-cloud-workflows)