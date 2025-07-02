# Creating the Xcode Project for C11S House

Since `.xcodeproj` files must be created by Xcode itself, follow these steps:

## Quick Setup

1. **Create the Xcode Project**
   ```
   1. Open Xcode
   2. File → New → Project
   3. Choose: iOS → App
   4. Configure:
      - Product Name: C11SHouse
      - Bundle ID: com.c11s.house
      - Interface: SwiftUI
      - Language: Swift
   5. Save in: /workspaces/c11s-house-ios/
      (It's OK to let Xcode create the C11SHouse directory)
   6. Close Xcode
   ```

2. **Run the Setup Script**
   ```bash
   ./setup_xcode_project.sh
   ```

3. **Open in Xcode and Configure**
   - Open `C11SHouse.xcodeproj`
   - Select your development team
   - Verify bundle ID is `com.c11s.house`

4. **Enable Xcode Cloud**
   - Product → Xcode Cloud → Create Workflow
   - Follow the setup wizard

## What's Included

- **Source Files**: Basic SwiftUI app structure
- **Xcode Cloud Workflows**: 
  - CI (build & test on PRs)
  - Beta (TestFlight releases)
  - Release (App Store submissions)
- **CI Scripts**: Build number management
- **Test Targets**: Unit and UI test templates

## Manual Alternative

If you prefer to set up manually:

1. Create new Xcode project as above
2. Replace the generated files with ones from `xcode-templates/` directory
3. Copy `xcode-templates/.xcode/workflows/` to your project root  
4. Copy `xcode-templates/ci_scripts/` to your project root

## Next Steps

See [XCODE_CLOUD_SETUP.md](XCODE_CLOUD_SETUP.md) for detailed Xcode Cloud configuration.