# Device Database Documentation Index

This directory contains comprehensive documentation about the device information system in ScreenTimeCapsule. Choose the document that best matches your needs:

## Documents Overview

### 1. DEVICE_QUICK_REFERENCE.md (6.7 KB, 241 lines)
**Best for**: Quick lookup, debugging, getting started

**Contents**:
- Database locations and paths
- ZDEVICE table schema (SQL)
- DeviceInfo Swift model definition
- Core Data timestamp conversion
- Key methods overview
- ZOBJECT table schema
- Data flow diagram
- Common queries
- File locations in project
- Error handling
- Debugging tips
- Performance considerations

**When to use**: 
- Need a quick answer
- Looking up a specific method
- Debugging issues
- Need database paths

---

### 2. DEVICE_DATABASE_GUIDE.md (15 KB, 421 lines)
**Best for**: Deep understanding, comprehensive reference

**Contents**:
- Complete database architecture overview
- Knowledge database (knowledgeC.db) details
- Screen Time database (RMAdminStore-Local.sqlite) details
- Multiple database file structure
- Full Swift data models with code
- Device data fetching implementation details
- Timestamp conversion mechanics
- Complete data flow architecture
- Recent implementation changes (Commit 0dd719f)
- Usage examples
- Permissions requirements
- Data persistence and backup strategy
- Database limitations and notes
- Testing and debugging guide
- References and related files

**When to use**:
- Want to understand how everything works
- Need implementation details
- Reviewing recent changes
- Planning new features
- Understanding the overall architecture

---

### 3. DEVICE_API_EXAMPLES.md (12 KB, 400 lines)
**Best for**: Practical usage, code examples, integration

**Contents**:
- Device picker implementation (ContentView)
- Display device info in views
- List all available devices
- Device breakdown charts
- Direct DatabaseManager queries
- Load devices programmatically
- Watch device selection changes
- Create DeviceInfo objects
- Compare devices
- Real-world scenarios:
  - Compare usage across devices
  - Find most used device
  - Export device report
- Testing examples with XCTest
- Common patterns:
  - Device selection with fallback
  - Safe device lookup
  - Device change handlers
  - Async device loading

**When to use**:
- Writing new features
- Need code examples
- Implementing UI components
- Testing device functionality
- Want real-world use cases

---

## Quick Navigation

### By Task

#### "I need to add a feature that shows all devices"
1. Start with: **DEVICE_QUICK_REFERENCE.md** - See "Key Methods"
2. Reference: **DEVICE_API_EXAMPLES.md** - Example 3 "List All Available Devices"
3. Deep dive: **DEVICE_DATABASE_GUIDE.md** - Section "Usage Examples"

#### "I need to debug why devices aren't showing"
1. Check: **DEVICE_QUICK_REFERENCE.md** - "Debugging Tips"
2. Reference: **DEVICE_DATABASE_GUIDE.md** - "Testing & Debugging"
3. Look at: **DEVICE_DATABASE_GUIDE.md** - "Database Limitations"

#### "I need to understand how device data flows through the app"
1. Read: **DEVICE_DATABASE_GUIDE.md** - "Data Flow" section
2. Reference: **DEVICE_QUICK_REFERENCE.md** - "Data Flow Diagram"
3. Examples: **DEVICE_API_EXAMPLES.md** - Any "Example" section

#### "I need to filter app usage by device"
1. Check: **DEVICE_API_EXAMPLES.md** - Example 5
2. Reference: **DEVICE_API_EXAMPLES.md** - "Scenario 1: Compare Usage"
3. Details: **DEVICE_DATABASE_GUIDE.md** - "Query Examples"

#### "I need to add tests for device functionality"
1. See: **DEVICE_API_EXAMPLES.md** - Example 10
2. Reference: **DEVICE_DATABASE_GUIDE.md** - "Testing & Debugging"

---

## Key Concepts Summary

### Database Files
- **knowledgeC.db**: App usage events (ZOBJECT table)
- **RMAdminStore-Local.sqlite**: Local device (ZDEVICE table)
- **RMAdminStore-iCloud~*.sqlite**: Synced devices from iPhone/iPad

### Main Tables

#### ZDEVICE (Device Information)
```sql
CREATE TABLE ZDEVICE (
    ZIDENTIFIER TEXT PRIMARY KEY,   -- Device ID
    ZNAME TEXT,                     -- Device name
    ZMODEL TEXT,                    -- Device model (Mac, iPhone, iPad)
    ZLASTSEENDATE REAL,             -- Last seen timestamp
);
```

#### ZOBJECT (App Usage Events)
```sql
CREATE TABLE ZOBJECT (
    ZSTARTDATE REAL,                -- Event start
    ZENDDATE REAL,                  -- Event end (optional)
    ZVALUESTRING TEXT,              -- App bundle ID
    ZSTREAMNAME TEXT,               -- Stream type
);
```

### Core Swift Types

#### DeviceInfo
```swift
struct DeviceInfo: Identifiable, Codable, Hashable {
    let id: String              // Device identifier
    let name: String            // Friendly name
    let model: String           // Device model
    let lastSeen: Date          // Last usage
}
```

#### Key Properties in ScreenTimeDataManager
```swift
@Published var devices: [DeviceInfo]      // All available devices
@Published var selectedDevice: DeviceInfo? // Currently selected device
@Published var currentUsage: [AppUsage]   // Usage for selected device
@Published var usageSummary: UsageSummary? // Statistics
```

---

## Data Loading Flow

```
App Launch
    ↓
ScreenTimeDataManager.loadDevices()
    ↓
DatabaseManager.fetchDevices()
    ↓
Scan ~/Library/Application Support/com.apple.screentime/
    ↓
Query ZDEVICE table from all .sqlite files
    ↓
Deduplicate by device ID
    ↓
Return [DeviceInfo] sorted by name
    ↓
User selects device → refreshData()
    ↓
DatabaseManager.fetchAppUsage()
    ↓
Filter by selected device & date range
    ↓
UI updates
```

---

## Implementation Highlights

### Recent Changes (Commit 0dd719f)
**Feature**: "Scan all Screen Time databases for devices"

- Now scans ALL .sqlite files (not just RMAdminStore-Local.sqlite)
- Properly deduplicates devices by ID using dictionary
- Includes lastSeen timestamp for each device
- Handles iCloud-synced devices from iPhone/iPad
- Better error handling and logging

**Files Modified**:
- `/home/user/ScreenTimeCapsule/ScreenTimeCapsule/Sources/Managers/DatabaseManager.swift`

---

## Permissions & Requirements

### Full Disk Access
- **Required**: To read protected Apple Screen Time databases
- **Check**: `DatabaseManager.checkDatabaseAccess()`
- **Request**: `ScreenTimeDataManager.requestFullDiskAccess()`

### Data Retention
- Apple keeps ~28 days of detailed data
- Regular backups recommended
- `DatabaseManager.copyDatabaseToBackup()`

---

## Troubleshooting Quick Links

| Issue | Reference |
|-------|-----------|
| "No devices found" | DEVICE_QUICK_REFERENCE.md > Error Handling |
| Duplicate devices | DEVICE_QUICK_REFERENCE.md > Debugging Tips |
| Wrong device model | DEVICE_DATABASE_GUIDE.md > Database Limitations |
| Permission denied | DEVICE_DATABASE_GUIDE.md > Permissions Requirements |
| Can't filter by device | DEVICE_API_EXAMPLES.md > Example 5 |

---

## Related Documentation

Other relevant documents in the project:
- **README.md** - Project overview
- **PROJECT_STRUCTURE.md** - Project organization
- **TECHNICAL_NOTES.md** - Database overview
- **BUILD.md** - Build instructions
- **CONTRIBUTING.md** - Contribution guidelines

---

## File Statistics

| Document | Size | Lines | Focus |
|----------|------|-------|-------|
| DEVICE_QUICK_REFERENCE.md | 6.7 KB | 241 | Quick lookup |
| DEVICE_DATABASE_GUIDE.md | 15 KB | 421 | Comprehensive |
| DEVICE_API_EXAMPLES.md | 12 KB | 400 | Practical |

**Total**: 34 KB, 1,062 lines of documentation

---

## How to Update This Documentation

1. **For database schema changes**: Update DEVICE_DATABASE_GUIDE.md
2. **For new API methods**: Add to DEVICE_API_EXAMPLES.md
3. **For quick fixes**: Update DEVICE_QUICK_REFERENCE.md
4. **For new features**: Document in all three files

---

## Feedback & Improvements

These documents were created to help understand and work with the device database. If you find:
- **Gaps in documentation**: Add missing sections
- **Unclear explanations**: Improve with better examples
- **New use cases**: Add to DEVICE_API_EXAMPLES.md
- **Code changes**: Update relevant sections

---

**Last Updated**: January 21, 2026
**Documentation Version**: 1.0
**Covers Commit**: 0dd719f (feat: Scan all Screen Time databases for devices)
