# Project Structure

This document describes the organization and architecture of ScreenTimeCapsule.

## Directory Layout

```
ScreenTimeCapsule/
├── Sources/                    # Application source code
│   ├── ScreenTimeCapsuleApp.swift   # App entry point & SwiftUI App
│   ├── Models/                 # Data models
│   │   └── AppUsage.swift      # Usage data models
│   ├── Managers/               # Business logic layer
│   │   ├── DatabaseManager.swift           # Screen Time DB access
│   │   ├── BackupManager.swift             # Backup operations
│   │   └── ScreenTimeDataManager.swift     # Data aggregation
│   └── Views/                  # SwiftUI views
│       ├── ContentView.swift           # Main app view
│       ├── UsageChartView.swift        # Charts and graphs
│       ├── AppListView.swift           # App usage list
│       ├── PermissionView.swift        # Full Disk Access flow
│       └── SettingsView.swift          # Settings panel
├── Resources/                  # App resources
│   ├── Info.plist              # App metadata
│   └── ScreenTimeCapsule.entitlements  # Security entitlements
├── Tests/                      # Unit tests (to be added)
├── Package.swift               # Swift Package Manager config
├── Makefile                    # Build automation
├── setup.sh                    # Development setup script
├── README.md                   # User documentation
├── BUILD.md                    # Build instructions
├── CONTRIBUTING.md             # Contribution guidelines
├── CHANGELOG.md                # Version history
├── TECHNICAL_NOTES.md          # Database documentation
└── .gitignore                  # Git ignore rules
```

## Architecture

### Layer Separation

```
┌─────────────────────────────────────┐
│         SwiftUI Views               │  ← Presentation
├─────────────────────────────────────┤
│         Data Managers               │  ← Business Logic
├─────────────────────────────────────┤
│      Database & File Access         │  ← Data Access
└─────────────────────────────────────┘
```

### Component Overview

#### 1. Presentation Layer (Views/)

**ContentView.swift**
- Main application interface
- Navigation split view layout
- Device selector
- Time period selector
- Category filtering

**UsageChartView.swift**
- Hourly usage bar charts
- Weekly usage visualizations
- Category breakdown displays
- Uses Swift Charts framework

**AppListView.swift**
- Searchable app usage list
- App icons and metadata
- Category filtering
- Usage time display

**PermissionView.swift**
- Full Disk Access request flow
- Setup instructions
- Permission status checking

**SettingsView.swift**
- Tabbed settings interface
- General, Backup, and Data tabs
- Backup configuration
- Data retention settings
- Backup statistics

#### 2. Business Logic Layer (Managers/)

**ScreenTimeDataManager.swift**
- Central data coordinator
- Aggregates usage data
- Time period calculations
- Category breakdowns
- Device filtering
- Observable state management

**BackupManager.swift**
- Backup scheduling
- Automatic backup timers
- Manual backup triggers
- Data retention enforcement
- Old backup cleanup
- Export functionality

**DatabaseManager.swift**
- Low-level database access
- Reads knowledgeC.db
- Reads RMAdminStore-Local.sqlite
- SQL query execution
- Device information extraction
- App categorization

#### 3. Data Model Layer (Models/)

**AppUsage.swift**
- Core data structures
- `AppUsage`: Individual app usage record
- `UsageCategory`: App categories
- `DeviceInfo`: Device metadata
- `UsageSummary`: Aggregated statistics
- `TimePeriod`: Time range definitions
- `BackupStatus`: Backup state

### Data Flow

```
┌──────────────┐
│  User Input  │
└──────┬───────┘
       │
       ▼
┌────────────────────┐
│  SwiftUI Views     │
│  @EnvironmentObject│
└─────────┬──────────┘
          │
          ▼
┌──────────────────────────┐
│  ScreenTimeDataManager   │ ◄─── @Published properties
│  (ObservableObject)      │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────┐
│  DatabaseManager     │
│  (Singleton)         │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Screen Time DBs     │
│  - knowledgeC.db     │
│  - RMAdminStore      │
└──────────────────────┘
```

### State Management

ScreenTimeCapsule uses Combine and SwiftUI's reactive programming:

1. **@Published Properties**: Data managers publish changes
2. **@EnvironmentObject**: Views observe managers
3. **Automatic UI Updates**: SwiftUI reacts to published changes

Example:
```swift
class ScreenTimeDataManager: ObservableObject {
    @Published var currentUsage: [AppUsage] = []
    @Published var isLoading = false

    func refreshData() {
        isLoading = true
        // Fetch data...
        currentUsage = fetchedData
        isLoading = false
    }
}
```

### Database Access Pattern

```
User Action
    ↓
ScreenTimeDataManager.refreshData()
    ↓
DatabaseManager.fetchAppUsage(from:to:)
    ↓
SQLite Query on knowledgeC.db
    ↓
Parse Results → [AppUsage]
    ↓
Update @Published property
    ↓
SwiftUI View Auto-Updates
```

## Key Technologies

### Frameworks
- **SwiftUI**: Declarative UI framework
- **Swift Charts**: Native charting
- **Combine**: Reactive programming
- **Foundation**: Core utilities

### Dependencies
- **SQLite.swift**: Type-safe database access
  - Version: 0.15.0+
  - Purpose: Read Screen Time databases

### System APIs
- **FileManager**: File operations
- **UserDefaults**: User preferences
- **NSWorkspace**: App metadata and icons
- **IOKit**: Device identification

## Code Conventions

### Naming
- **Types**: UpperCamelCase (`AppUsage`, `BackupManager`)
- **Properties/Methods**: lowerCamelCase (`totalTime`, `fetchAppUsage`)
- **Constants**: lowerCamelCase (`maximumRetentionDays`)

### File Organization
```swift
// MARK: - Type Definition

class MyClass {
    // MARK: - Properties

    // MARK: - Initialization

    // MARK: - Public Methods

    // MARK: - Private Methods

    // MARK: - Helper Types
}
```

### SwiftUI Views
- Keep views small and focused
- Extract complex views
- Use computed properties for data transformations
- Environment objects for shared state

## Security Model

### App Sandbox
- Enabled via entitlements
- Limited file system access
- Security scope bookmarks for user-selected folders

### Required Permissions
- **Full Disk Access**: Read Screen Time databases
- **File Access**: User-selected backup location

### Data Privacy
- No network access
- All data stays local
- No telemetry or analytics
- Open source code

## Build Configuration

### Debug Build
- Assertions enabled
- Debug symbols included
- No optimization
- Fast compilation

### Release Build
- Optimizations enabled (-O)
- Whole module optimization
- Debug symbols stripped
- Code signing required

## Testing Strategy (Future)

### Unit Tests
- Test business logic in Managers
- Mock database access
- Verify data transformations

### UI Tests
- Test navigation flows
- Verify permission screens
- Test settings changes

### Integration Tests
- Test with sample databases
- Verify backup/restore cycle
- Test multi-device scenarios

## Performance Considerations

### Database Queries
- Use prepared statements
- Index frequently queried columns
- Limit result sets with date ranges

### Memory Management
- Lazy loading for large datasets
- Pagination for app lists
- Release unused resources

### UI Responsiveness
- Async database operations
- Background processing for backups
- Progress indicators for long operations

## Future Architecture

### Planned Improvements
- Core Data for local storage
- CloudKit sync (optional)
- Plugin system for exporters
- Scriptable with AppleScript
- Menu bar app mode

### Extensibility Points
- Custom export formats
- Additional data sources
- Custom visualizations
- Notification plugins

## Dependencies

```
ScreenTimeCapsule
└── SQLite.swift (~> 0.15.0)
    └── No further dependencies
```

Minimal dependency tree for security and maintainability.

## Build Outputs

### Development
- `.build/debug/ScreenTimeCapsule` - Debug executable

### Release
- `.build/release/ScreenTimeCapsule` - Optimized executable
- `ScreenTimeCapsule.app` - macOS app bundle

### Distribution
- `ScreenTimeCapsule.zip` - Notarized app archive
- DMG installer (future)

## Documentation

### User Documentation
- README.md: Getting started
- BUILD.md: Build instructions

### Developer Documentation
- CONTRIBUTING.md: Development guidelines
- TECHNICAL_NOTES.md: Database schema
- This file: Architecture overview

### Code Documentation
- Swift doc comments for public APIs
- Inline comments for complex logic
- README files in each major directory

---

For questions about the architecture, please see [CONTRIBUTING.md](CONTRIBUTING.md) or open an issue.
