# Building ScreenTimeCapsule

This guide covers building ScreenTimeCapsule from source.

## Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9 or later
- Command Line Tools installed

## Quick Start

### Using Swift Package Manager

The fastest way to build:

```bash
# Clone the repository
git clone https://github.com/yourusername/ScreenTimeCapsule.git
cd ScreenTimeCapsule

# Build in release mode
swift build -c release

# Run the app
.build/release/ScreenTimeCapsule
```

### Using Xcode

1. Open the package in Xcode:
```bash
open Package.swift
```

2. Wait for dependencies to resolve
3. Select the "ScreenTimeCapsule" scheme
4. Press ⌘R to build and run

## Building for Distribution

### Create App Bundle

To create a proper macOS app bundle:

```bash
# Build in release mode
swift build -c release

# Create app bundle structure
mkdir -p "ScreenTimeCapsule.app/Contents/MacOS"
mkdir -p "ScreenTimeCapsule.app/Contents/Resources"

# Copy executable
cp .build/release/ScreenTimeCapsule "ScreenTimeCapsule.app/Contents/MacOS/"

# Copy Info.plist
cp Resources/Info.plist "ScreenTimeCapsule.app/Contents/"

# Copy entitlements (for signing)
cp Resources/ScreenTimeCapsule.entitlements "ScreenTimeCapsule.app/Contents/"
```

### Code Signing

To distribute the app, you need to sign it:

```bash
# Sign the app
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  --options runtime \
  --entitlements Resources/ScreenTimeCapsule.entitlements \
  ScreenTimeCapsule.app

# Verify signature
codesign --verify --verbose ScreenTimeCapsule.app
spctl --assess --verbose ScreenTimeCapsule.app
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
