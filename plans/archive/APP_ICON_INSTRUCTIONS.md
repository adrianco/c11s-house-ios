# App Icon Design Instructions: House with Brain

## Design Concept
A modern, minimalist icon featuring a house silhouette with a brain inside, representing the "conscious house" concept.

## Quick Creation Methods

### Method 1: Using the Provided Code
1. Open `CreateAppIcon.swift` in Xcode
2. Create a temporary SwiftUI preview or playground
3. Run the code to generate the icon
4. Export at 1024x1024 resolution

### Method 2: Using Design Tools

#### Figma/Sketch Design:
1. **Background**: Blue to purple gradient (45° angle)
   - Top-left: #007AFF (System Blue)
   - Bottom-right: #AF52DE (System Purple)

2. **House Shape**:
   - Simple house silhouette with triangular roof
   - White color with 90% opacity
   - Size: 60% of canvas
   - Centered

3. **Brain Icon**:
   - Placed inside the house
   - White color, 100% opacity
   - Size: 30% of canvas
   - Centered within house

### Method 3: Using SF Symbols (Easiest)
1. Download SF Symbols app from Apple
2. Export "house.fill" and "brain.head.profile" symbols
3. Combine in any image editor
4. Apply gradient background

## Icon Sizes Needed
- 1024x1024px - App Store
- 180x180px - iPhone (60pt @3x)
- 120x120px - iPhone (60pt @2x)
- 152x152px - iPad (76pt @2x)
- 167x167px - iPad Pro (83.5pt @2x)

## How to Add to Project
1. Generate the 1024x1024 master icon
2. In Xcode, select Assets.xcassets
3. Select AppIcon
4. Drag your 1024x1024 icon to the slot
5. Xcode will automatically generate all required sizes

## Alternative Free Tools
- **Canva**: Free templates for app icons
- **IconSet**: Mac app for generating all sizes
- **Bakery**: Sketch plugin for app icon export
- **makeappicon.com**: Web tool to generate all sizes

## Color Palette
- Primary: #007AFF (Blue)
- Secondary: #AF52DE (Purple)
- Icon: #FFFFFF (White)

## Design Tips
- Keep it simple and recognizable at small sizes
- Use bold shapes without fine details
- Ensure good contrast
- Test on both light and dark backgrounds