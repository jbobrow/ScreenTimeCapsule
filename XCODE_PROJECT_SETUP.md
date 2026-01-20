# Creating a Proper Xcode Project

The current setup uses Swift Package Manager (SPM), which is great for libraries but not ideal for full macOS applications with resources, entitlements, and proper app bundles.

## Why You Need an Xcode Project

1. **App Bundle Structure** - Proper macOS apps need Info.plist, entitlements, and resources
2. **Code Signing** - Easier to manage in Xcode projects
3. **App Store Distribution** - Required for App Store submission
4. **Better Development Experience** - Build phases, schemes, and targets

## How to Create an Xcode Project

### Option 1: Use Xcode's File → New → Project (Recommended)

1. **Open Xcode**

2. **Create New Project**
   - File → New → Project
   - Choose "macOS" → "App"
   - Click "Next"

3. **Configure Project**
   - Product Name: `ScreenTimeCapsule`
   - Team: Your development team
   - Organization Identifier: `com.yourname` or similar
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Click "Next"

4. **Choose Location**
   - Save to a NEW directory (e.g., `ScreenTimeCapsule-Xcode`)
   - Don't overwrite the current SPM project yet

5. **Migrate Your Code**
   - Delete the default ContentView.swift and ScreenTimeCapsuleApp.swift from new project
   - Copy all files from `Sources/` to the new project's folder
   - In Xcode, right-click project → "Add Files to ScreenTimeCapsule"
   - Select all the files you copied
   - Make sure "Copy items if needed" is UNCHECKED (they're already there)
   - Make sure target is checked

6. **Add Resources**
   - Copy `Resources/Info.plist` content to new project's Info.plist
   - Add entitlements file: File → New → File → Property List
   - Name it `ScreenTimeCapsule.entitlements`
   - Copy content from `Resources/ScreenTimeCapsule.entitlements`

7. **Add Dependencies**
   - In Xcode, select your project in navigator
   - Select your app target
   - Go to "Frameworks, Libraries, and Embedded Content"
   - Click "+" → "Add Other" → "Add Package Dependency"
   - Enter: `https://github.com/stephencelis/SQLite.swift.git`
   - Choose version 0.15.0 or later

8. **Configure Entitlements**
   - Select your target → "Signing & Capabilities"
   - Enable "App Sandbox"
   - Add capability: "File Access" → "User Selected File" (Read/Write)

9. **Build and Run**
   - Press Cmd+B to build
   - Press Cmd+R to run

### Option 2: Convert SPM to Xcode Project

If you want to keep working from the current directory:

1. **In your project directory, run:**
   ```bash
   # Open Package.swift in Xcode
   open Package.swift
   ```

2. **File → Save As Workspace**
   - This creates a workspace that wraps your package

3. **Create an App Target**
   - You'll need to manually create target settings
   - This is more complex and not recommended

## Recommended Project Structure

```
ScreenTimeCapsule/
├── ScreenTimeCapsule.xcodeproj/          # Xcode project
├── ScreenTimeCapsule/                     # App source
│   ├── App/
│   │   └── ScreenTimeCapsuleApp.swift
│   ├── Models/
│   │   └── AppUsage.swift
│   ├── Managers/
│   │   ├── DatabaseManager.swift
│   │   ├── BackupManager.swift
│   │   └── ScreenTimeDataManager.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── UsageChartView.swift
│   │   ├── AppListView.swift
│   │   ├── PermissionView.swift
│   │   └── SettingsView.swift
│   ├── Resources/
│   │   └── Assets.xcassets
│   ├── Info.plist
│   └── ScreenTimeCapsule.entitlements
├── ScreenTimeCapsuleTests/               # Tests
└── README.md
```

## Quick Start Script

I've provided a script to help with the migration. After creating a new Xcode project:

```bash
# From your new Xcode project directory
cp -r /path/to/old/ScreenTimeCapsule/Sources/* ScreenTimeCapsule/
cp -r /path/to/old/ScreenTimeCapsule/Tests/* ScreenTimeCapsuleTests/
```

Then add the files in Xcode as described above.

## Important Notes

- **Keep the SPM version** as a backup until migration is complete
- **Update Info.plist** with proper bundle identifier
- **Configure Code Signing** in target settings
- **Test Full Disk Access** after migration - may need to re-grant permission
- **Update README** with new build instructions

## Troubleshooting

### "Cannot find [type] in scope"
- Make sure all files are added to the target (check File Inspector)
- Verify imports are correct (SwiftUI, AppKit, IOKit)

### "App crashes on launch"
- Check that Info.plist is properly configured
- Verify bundle identifier matches code signing

### "Full Disk Access doesn't work"
- You may need to remove and re-add the app in System Settings
- Make sure entitlements file is set in target settings

### "Cannot find SQLite module"
- Verify package dependency is added correctly
- Try Product → Clean Build Folder, then rebuild

## After Migration

Once your Xcode project works:

1. Update the README with new build instructions
2. Archive the SPM project for reference
3. Update build documentation
4. Test on a clean Mac to ensure setup works

## Need Help?

If you run into issues:
1. Check Build Settings → "Build Phases" → "Compile Sources" - all .swift files should be listed
2. Check target membership for each file
3. Clean derived data: Cmd+Shift+K
4. Restart Xcode

Good luck with the migration! 🚀
