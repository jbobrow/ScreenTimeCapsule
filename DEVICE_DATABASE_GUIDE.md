# ScreenTimeCapsule Device Database Guide

## Overview

This document details the device information structure in the ScreenTimeCapsule project, including how device data is stored in Apple's Screen Time databases and how it's accessed within the application.

## Database Architecture

### Two Key Databases

#### 1. Knowledge Database (knowledgeC.db)
**Location**: `~/Library/Application Support/Knowledge/knowledgeC.db`
**Purpose**: Contains detailed app usage events and metadata
**Key Tables**:
- **ZOBJECT**: Main events table with app usage records
- **ZSTRUCTUREDMETADATA**: Metadata for events
- **ZSOURCE**: Source applications info

**Relevant Schema**:
```sql
CREATE TABLE ZOBJECT (
    Z_PK INTEGER PRIMARY KEY,
    ZSTREAMNAME TEXT,                -- "/app/usage", "/app/inFocus", etc.
    ZSTARTDATE REAL,                 -- Event start (Core Data timestamp)
    ZENDDATE REAL,                   -- Event end (optional)
    ZVALUESTRING TEXT,               -- App bundle identifier
    ...
);
```

#### 2. Screen Time Database (RMAdminStore-Local.sqlite)
**Location**: `~/Library/Application Support/com.apple.screentime/RMAdminStore-Local.sqlite`
**Purpose**: Contains Screen Time settings, limits, and device information
**Key Table**: **ZDEVICE**

**ZDEVICE Schema**:
```sql
CREATE TABLE ZDEVICE (
    ZIDENTIFIER TEXT PRIMARY KEY,    -- Unique device ID
    ZNAME TEXT,                      -- Device friendly name
    ZMODEL TEXT,                     -- Device model (Mac, iPhone, iPad)
    ZLASTSEENDATE REAL,              -- Last seen timestamp
    ...
);
```

### Multiple Database Files

Screen Time creates separate database files for each synced device via iCloud:
```
~/Library/Application Support/com.apple.screentime/
├── RMAdminStore-Local.sqlite          -- Current device
├── RMAdminStore-iCloud~[UUID].sqlite  -- iCloud-synced device 1
├── RMAdminStore-iCloud~[UUID].sqlite  -- iCloud-synced device 2
└── ...
```

## Swift Data Models

### DeviceInfo Struct
**File**: `/home/user/ScreenTimeCapsule/ScreenTimeCapsule/Sources/Models/AppUsage.swift`

```swift
struct DeviceInfo: Identifiable, Codable, Hashable {
    let id: String           // Unique device identifier
    let name: String         // Device friendly name (e.g., "John's Mac")
    let model: String        // Device model (e.g., "Mac", "iPhone", "iPad")
    let lastSeen: Date       // Last usage timestamp
    
    init(id: String, name: String, model: String = "Unknown", lastSeen: Date = Date()) {
        self.id = id
        self.name = name
        self.model = model
        self.lastSeen = lastSeen
    }
}
```

### AppUsage Struct (Device-Related Fields)
```swift
struct AppUsage: Identifiable, Codable {
    let id: UUID
    let bundleIdentifier: String
    let appName: String
    let totalTime: TimeInterval
    let startDate: Date
    let endDate: Date
    let deviceIdentifier: String?    // <-- Maps to DeviceInfo.id
    let category: UsageCategory
}
```

### UsageSummary (Device Breakdown)
```swift
struct UsageSummary: Codable {
    let date: Date
    let totalTime: TimeInterval
    let categoryBreakdown: [UsageCategory: TimeInterval]
    let topApps: [AppUsage]
    let deviceBreakdown: [String: TimeInterval]  // <-- Device ID -> Total Time
}
```

## Device Data Fetching

### Implementation Details
**File**: `/home/user/ScreenTimeCapsule/ScreenTimeCapsule/Sources/Managers/DatabaseManager.swift`

#### Main Function: `fetchDevices()`

**Process**:
1. Checks if Screen Time directory exists
2. Scans for all `.sqlite` files
3. Queries ZDEVICE table from each database
4. Deduplicates devices by ID (dictionary key)
5. Sorts alphabetically by device name
6. Falls back to current device if no devices found

**Code Excerpt**:
```swift
func fetchDevices() throws -> [DeviceInfo] {
    var allDevices: [String: DeviceInfo] = [:]  // Deduplication
    
    // Scan ~/Library/Application Support/com.apple.screentime/ for all .sqlite files
    let contents = try fileManager.contentsOfDirectory(atPath: screenTimeDirectory)
    let sqliteFiles = contents.filter { $0.hasSuffix(".sqlite") }
    
    // Read devices from each database
    for filename in sqliteFiles {
        let dbPath = (screenTimeDirectory as NSString).appendingPathComponent(filename)
        let db = try Connection(dbPath, readonly: true)
        let devices = try fetchDevicesFromDatabase(db: db, source: filename)
        
        for device in devices {
            allDevices[device.id] = device  // Deduplicate by ID
        }
    }
    
    return Array(allDevices.values).sorted { $0.name < $1.name }
}
```

#### Helper Function: `fetchDevicesFromDatabase()`

```swift
private func fetchDevicesFromDatabase(db: Connection, source: String) throws -> [DeviceInfo] {
    var deviceList: [DeviceInfo] = []
    
    let devices = Table("ZDEVICE")
    let zId = Expression<String>("ZIDENTIFIER")
    let zName = Expression<String?>("ZNAME")
    let zModel = Expression<String?>("ZMODEL")
    let zLastSeen = Expression<Double?>("ZLASTSEENDATE")
    
    for row in try db.prepare(devices) {
        // Convert Core Data timestamp to Date
        var lastSeenDate = Date()
        if let lastSeenTimestamp = row[zLastSeen] {
            let referenceDate = Date(timeIntervalSinceReferenceDate: 0)
            lastSeenDate = Date(timeInterval: lastSeenTimestamp, since: referenceDate)
        }
        
        deviceList.append(DeviceInfo(
            id: row[zId],
            name: row[zName] ?? "Unknown Device",
            model: row[zModel] ?? "Unknown",
            lastSeen: lastSeenDate
        ))
    }
    
    return deviceList
}
```

## Timestamp Conversion

Apple's Core Data timestamps use a custom epoch: **2001-01-01T00:00:00Z**

**Conversion**:
```swift
let referenceDate = Date(timeIntervalSinceReferenceDate: 0)
let eventDate = Date(timeInterval: coreDataTimestamp, since: referenceDate)
```

**Reverse**:
```swift
let coreDataTimestamp = eventDate.timeIntervalSince(referenceDate)
```

## Data Flow in ScreenTimeCapsule

### Architecture Diagram
```
┌─────────────────────────────────────────────┐
│           Views (SwiftUI)                   │
│  - ContentView                              │
│  - AppListView                              │
│  - UsageChartView                           │
└────────────┬────────────────────────────────┘
             │ subscribes to
             ↓
┌─────────────────────────────────────────────┐
│    ScreenTimeDataManager (ObservableObject) │
│  @Published var devices: [DeviceInfo]       │
│  @Published var selectedDevice: DeviceInfo? │
│  @Published var currentUsage: [AppUsage]    │
│  @Published var usageSummary: UsageSummary? │
└────────────┬────────────────────────────────┘
             │ calls methods on
             ↓
┌─────────────────────────────────────────────┐
│        DatabaseManager (Singleton)          │
│  func fetchDevices() -> [DeviceInfo]        │
│  func fetchAppUsage(...) -> [AppUsage]      │
│  func fetchHourlyData(...) -> [...]         │
│  func fetchDailyData(...) -> [...]          │
└────────────┬────────────────────────────────┘
             │ reads from
             ↓
┌─────────────────────────────────────────────┐
│   Apple Screen Time Databases               │
│  - knowledgeC.db (ZOBJECT table)           │
│  - RMAdminStore-Local.sqlite (ZDEVICE)     │
│  - RMAdminStore-iCloud~*.sqlite            │
└─────────────────────────────────────────────┘
```

### Data Loading Flow
1. **App Launch**:
   - `ScreenTimeDataManager.init()` calls `checkPermissions()`
   - Calls `loadDevices()` which invokes `DatabaseManager.fetchDevices()`
   - Populates `@Published var devices: [DeviceInfo]`
   - Auto-selects first device as `selectedDevice`

2. **Device Selection Change**:
   - User selects different device
   - `selectedDevice` update triggers `$selectedDevice.sink`
   - Calls `refreshData()` to update usage for selected device

3. **Data Refresh**:
   - `refreshData()` calls `DatabaseManager.fetchAppUsage(from:to:)`
   - Filters usage by date range and device
   - Updates `@Published var currentUsage: [AppUsage]`
   - Calculates `usageSummary` with device breakdown

## Recent Implementation Changes

### Commit: `feat: Scan all Screen Time databases for devices` (0dd719f)

**Changes Made**:
- Enhanced `fetchDevices()` to scan all `.sqlite` files in Screen Time directory
- Added `fetchDevicesFromDatabase()` helper function
- Implemented deduplication by device ID across multiple databases
- Added `lastSeen` timestamp tracking
- Improved error handling and logging
- Ensures iCloud-synced devices from iPhone/iPad are detected

**Before**:
```swift
func fetchDevices() throws -> [DeviceInfo] {
    let db = try Connection(screenTimeDBPath, readonly: true)
    // Only read from single RMAdminStore-Local.sqlite file
}
```

**After**:
```swift
func fetchDevices() throws -> [DeviceInfo] {
    var allDevices: [String: DeviceInfo] = [:]
    
    let sqliteFiles = contents.filter { $0.hasSuffix(".sqlite") }
    for filename in sqliteFiles {
        let devices = try fetchDevicesFromDatabase(db: db, source: filename)
        for device in devices {
            allDevices[device.id] = device  // Deduplication
        }
    }
    
    return Array(allDevices.values).sorted { $0.name < $1.name }
}
```

## Usage Examples

### Fetching All Devices
```swift
let dataManager = ScreenTimeDataManager.shared
let devices = dataManager.devices  // Published property, automatically updated
```

### Filtering Usage by Device
```swift
let usage = try DatabaseManager.shared.fetchAppUsage(from: startDate, to: endDate)
let deviceUsage = usage.filter { $0.deviceIdentifier == selectedDevice.id }
```

### Accessing Device Breakdown
```swift
if let summary = dataManager.usageSummary {
    let deviceTimes = summary.deviceBreakdown  // [String: TimeInterval]
    for (deviceId, totalTime) in deviceTimes {
        print("Device \(deviceId): \(formatDuration(totalTime))")
    }
}
```

## Permissions Requirements

### Full Disk Access
The application requires **Full Disk Access** to read Apple's Screen Time databases, which are protected system files.

**Permission Check**:
```swift
func checkDatabaseAccess() -> Bool {
    do {
        let db = try Connection(knowledgeDBPath, readonly: true)
        _ = try db.scalar("SELECT COUNT(*) FROM sqlite_master") as? Int64
        return true  // Full Disk Access granted
    } catch {
        return false  // Full Disk Access not granted
    }
}
```

**Requesting Permission**:
```swift
func requestFullDiskAccess() {
    let prefPaneURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
    NSWorkspace.shared.open(prefPaneURL)
}
```

## Data Persistence & Backup

### Backup Strategy
The app backs up both databases to preserve historical data:

```swift
func copyDatabaseToBackup(destinationURL: URL) throws {
    // Copies:
    // 1. knowledgeC.db + WAL/SHM files
    // 2. RMAdminStore-Local.sqlite + WAL/SHM files
    // 3. All RMAdminStore-iCloud~*.sqlite files
}
```

### File Structure
```
~/Library/Application Support/
├── Knowledge/
│   ├── knowledgeC.db              # Main events
│   ├── knowledgeC.db-wal          # Write-Ahead Log
│   └── knowledgeC.db-shm          # Shared Memory
└── com.apple.screentime/
    ├── RMAdminStore-Local.sqlite      # Local device
    ├── RMAdminStore-iCloud~[UUID].sqlite  # Remote device 1
    ├── RMAdminStore-iCloud~[UUID].sqlite  # Remote device 2
    ├── RMAdminStore-Local.sqlite-wal
    ├── RMAdminStore-Local.sqlite-shm
    └── ... (WAL/SHM for other databases)
```

## Database Limitations & Notes

### Data Retention
- Apple keeps ~28 days of detailed, granular data
- Older data is automatically aggregated and summarized
- Regular backups are essential for preserving historical data

### Missing Device Information
- If ZDEVICE table is empty or missing, app falls back to current device
- Only devices with recorded app usage appear in ZDEVICE
- Newly added devices may not appear until they have usage data

### Timestamp Quirks
- Events without `ZENDDATE` are assigned a default duration of 60 seconds
- Some events may have `ZSTARTDATE` but no `ZENDDATE`
- Timestamps are stored as Core Data epoch (2001-01-01)

## Testing & Debugging

### Enable Logging
The DatabaseManager includes detailed logging for debugging:

```swift
print("🔍 Scanning Screen Time directory: \(screenTimeDirectory)")
print("📁 Found \(sqliteFiles.count) database files:")
print("✅ Successfully read \(devices.count) device(s) from \(filename)")
print("📱 Total unique devices found: \(allDevices.count)")
```

### Common Issues

1. **No devices returned**:
   - Check if Screen Time directory exists
   - Verify Full Disk Access is granted
   - Confirm ZDEVICE table exists in database
   - Check logs for SQLite errors

2. **Duplicate devices**:
   - Should not occur with current deduplication logic
   - Dictionary key by device ID prevents duplicates

3. **Wrong device model**:
   - ZMODEL field in database may be missing
   - Falls back to "Unknown"
   - Verify database content with sqlite3 CLI

## References

- **SQLite Library**: SQLite.swift (SPM/Xcode dependency)
- **Core Data Epoch**: `Date(timeIntervalSinceReferenceDate:)`
- **File System**: FileManager standard library
- **IOKit**: For device UUID detection via IOPlatformExpertDevice

## Related Files

- Model: `/home/user/ScreenTimeCapsule/ScreenTimeCapsule/Sources/Models/AppUsage.swift`
- Database: `/home/user/ScreenTimeCapsule/ScreenTimeCapsule/Sources/Managers/DatabaseManager.swift`
- Data Manager: `/home/user/ScreenTimeCapsule/ScreenTimeCapsule/Sources/Managers/ScreenTimeDataManager.swift`
- Views: `/home/user/ScreenTimeCapsule/ScreenTimeCapsule/Sources/Views/`
