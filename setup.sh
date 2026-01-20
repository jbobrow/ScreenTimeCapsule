#!/bin/bash

# ScreenTimeCapsule Setup Script
# This script helps set up the development environment

set -e

echo "========================================="
echo "ScreenTimeCapsule Development Setup"
echo "========================================="
echo ""

# Check macOS version
echo "Checking system requirements..."
MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=$(echo $MACOS_VERSION | cut -d '.' -f 1)

if [ "$MACOS_MAJOR" -lt 14 ]; then
    echo "❌ Error: macOS 14.0 or later required (you have $MACOS_VERSION)"
    exit 1
fi
echo "✓ macOS version: $MACOS_VERSION"

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Xcode not found. Please install Xcode from the App Store."
    exit 1
fi
XCODE_VERSION=$(xcodebuild -version | head -n 1)
echo "✓ $XCODE_VERSION installed"

# Check for Swift
if ! command -v swift &> /dev/null; then
    echo "❌ Error: Swift not found. Please install Xcode Command Line Tools."
    echo "Run: xcode-select --install"
    exit 1
fi
SWIFT_VERSION=$(swift --version | head -n 1)
echo "✓ $SWIFT_VERSION"

# Check for Command Line Tools
if ! xcode-select -p &> /dev/null; then
    echo "⚠️  Command Line Tools not found. Installing..."
    xcode-select --install
    echo "Please complete the Command Line Tools installation and run this script again."
    exit 1
fi
echo "✓ Command Line Tools installed"

echo ""
echo "Resolving Swift package dependencies..."
swift package resolve

if [ $? -eq 0 ]; then
    echo "✓ Dependencies resolved successfully"
else
    echo "❌ Error resolving dependencies"
    exit 1
fi

echo ""
echo "Building project (debug mode)..."
swift build

if [ $? -eq 0 ]; then
    echo "✓ Build successful"
else
    echo "❌ Build failed"
    exit 1
fi

echo ""
echo "========================================="
echo "Setup Complete! 🎉"
echo "========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Open the project in Xcode:"
echo "   $ make xcode"
echo ""
echo "2. Or build and run from command line:"
echo "   $ make run"
echo ""
echo "3. Or build a release version:"
echo "   $ make release"
echo ""
echo "4. View all available commands:"
echo "   $ make help"
echo ""
echo "Important: Don't forget to grant Full Disk Access!"
echo "System Settings → Privacy & Security → Full Disk Access"
echo ""
echo "For more information, see:"
echo "- README.md for usage instructions"
echo "- BUILD.md for build options"
echo "- CONTRIBUTING.md for development guidelines"
echo ""
