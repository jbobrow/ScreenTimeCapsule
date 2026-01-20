# Building ScreenTimeCapsule

This guide covers building ScreenTimeCapsule from source using Xcode.

## Prerequisites

- **macOS 14.0 (Sonoma) or later**
- **Xcode 15.0 or later**
- **Swift 5.9 or later**
- **Apple Developer account** (for code signing)

## Quick Start

### Building in Xcode

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/ScreenTimeCapsule.git
   cd ScreenTimeCapsule
   ```

2. **Open the Xcode project:**
   ```bash
   open ScreenTimeCapsule.xcodeproj
   ```

   Or double-click `ScreenTimeCapsule.xcodeproj` in Finder

3. **Wait for package dependencies to resolve:**
   - Xcode will automatically fetch SQLite.swift
   - Check the progress in the status bar

4. **Select your development team:**
   - Click on the project in the navigator
   - Select the "ScreenTimeCapsule" target
   - Go to "Signing & Capabilities" tab
   - Choose your team from the dropdown

5. **Build and run:**
   - Press **⌘R** to build and run
   - Or select **Product → Run**

### Debug Build (Development)

The default build is a debug build, optimized for development:

```bash
# From Xcode
⌘B  # Build
⌘R  # Build and Run
```

The debug app will be located at:
```
~/Library/Developer/Xcode/DerivedData/ScreenTimeCapsule-.../Build/Products/Debug/ScreenTimeCapsule.app
```

## Building for Distribution

### Release Build

To create an optimized release build in Xcode:

1. **Select Release scheme:**
   - Product → Scheme → Edit Scheme
   - Select "Run" on the left
   - Change "Build Configuration" to "Release"
   - Click "Close"

2. **Build:**
   - Press **⌘B** to build
   - Release app will be at:
     ```
     ~/Library/Developer/Xcode/DerivedData/ScreenTimeCapsule-.../Build/Products/Release/ScreenTimeCapsule.app
     ```

### Archive for Distribution

To create a distributable archive:

1. **Set Generic Mac destination:**
   - Click the destination selector in the toolbar
   - Choose "Any Mac"

2. **Archive the app:**
   - Product → Archive
   - Wait for the build to complete
   - Organizer window will open automatically

3. **Export the app:**
   - Select your archive in the Organizer
   - Click "Distribute App"
   - Choose distribution method:
     - **Developer ID**: For distribution outside the Mac App Store
     - **Mac App Store**: For App Store submission
     - **Copy App**: For local testing
   - Follow the prompts to sign and export

### Code Signing (Automatic)

Xcode handles code signing automatically if configured correctly:

1. **Verify signing settings:**
   - Select your target
   - Go to "Signing & Capabilities"
   - Ensure "Automatically manage signing" is checked
   - Select your development team

2. **Check entitlements:**
   - Verify `ScreenTimeCapsule.entitlements` is set in Build Settings
   - Required entitlements:
     - App Sandbox
     - User Selected File (Read/Write)

3. **Verify signature:**
   ```bash
   codesign --verify --deep --verbose=2 ScreenTimeCapsule.app
   codesign -d --entitlements - ScreenTimeCapsule.app
   ```

### Notarization

For distribution outside the App Store:

```bash
# Create a zip archive
ditto -c -k --keepParent ScreenTimeCapsule.app ScreenTimeCapsule.zip

# Submit for notarization
xcrun notarytool submit ScreenTimeCapsule.zip \
  --apple-id "your@email.com" \
  --team-id "TEAM_ID" \
  --password "app-specific-password" \
  --wait

# Staple the notarization ticket
xcrun stapler staple ScreenTimeCapsule.app
```

## Development Build

For development and testing:

```bash
# Build in debug mode
swift build

# Run with debugging
swift run

# Run tests
swift test
```

## Dependencies

ScreenTimeCapsule uses Swift Package Manager for dependency management. Dependencies are automatically resolved:

- **SQLite.swift** (0.15.0+): Type-safe SQLite database interface

To update dependencies:

```bash
swift package update
```

## Build Configurations

### Debug Build

Includes debug symbols and assertions:

```bash
swift build -c debug
```

### Release Build

Optimized for performance:

```bash
swift build -c release
```

### Custom Build Flags

```bash
# Build with specific Swift flags
swift build -Xswiftc -O -Xswiftc -whole-module-optimization

# Build with sanitizers (for debugging)
swift build --sanitize=thread
swift build --sanitize=address
```

## Troubleshooting

### "Package.resolved" conflicts

```bash
rm Package.resolved
swift package resolve
```

### Build cache issues

```bash
swift package clean
swift build
```

### Dependency resolution fails

```bash
swift package update
swift package resolve
```

### Xcode build issues

1. Clean build folder: Product → Clean Build Folder (⌘⇧K)
2. Reset package caches: File → Packages → Reset Package Caches
3. Resolve package versions: File → Packages → Resolve Package Versions

## Architecture-Specific Builds

### Apple Silicon (arm64)

```bash
swift build -c release --arch arm64
```

### Intel (x86_64)

```bash
swift build -c release --arch x86_64
```

### Universal Binary

```bash
# Build for both architectures
swift build -c release --arch arm64
swift build -c release --arch x86_64

# Create universal binary with lipo
lipo -create \
  .build/arm64-apple-macosx/release/ScreenTimeCapsule \
  .build/x86_64-apple-macosx/release/ScreenTimeCapsule \
  -output ScreenTimeCapsule-universal
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Build

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-14
    steps:
    - uses: actions/checkout@v3
    - name: Build
      run: swift build -c release
    - name: Run tests
      run: swift test
```

## Performance Profiling

### Build with profiling enabled

```bash
swift build -c release --enable-code-coverage
```

### Profile in Xcode

1. Product → Profile (⌘I)
2. Choose "Time Profiler" or "Allocations"
3. Analyze performance bottlenecks

## Static Analysis

### SwiftLint

```bash
# Install SwiftLint
brew install swiftlint

# Run linter
swiftlint lint

# Auto-fix issues
swiftlint --fix
```

## Documentation

### Generate Documentation

```bash
# Using Swift-DocC
swift package generate-documentation

# Build documentation bundle
xcodebuild docbuild -scheme ScreenTimeCapsule \
  -derivedDataPath ./docbuild
```

## Common Issues

### Missing Full Disk Access

The app requires Full Disk Access even during development. Grant access in:
System Settings → Privacy & Security → Full Disk Access

### SQLite.swift not found

```bash
swift package resolve
swift package update
```

### Code signing errors

Ensure you have a valid Developer ID certificate in Keychain Access.

---

For more information, see the main [README](README.md).
