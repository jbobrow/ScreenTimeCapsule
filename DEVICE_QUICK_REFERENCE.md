# Device Database Quick Reference

## Database Locations

| Database | Path | Purpose |
|----------|------|---------|
| Knowledge | `~/Library/Application Support/Knowledge/knowledgeC.db` | App usage events |
| Screen Time (Local) | `~/Library/Application Support/com.apple.screentime/RMAdminStore-Local.sqlite` | Device info, settings |
| Screen Time (iCloud) | `~/Library/Application Support/com.apple.screentime/RMAdminStore-iCloud~[UUID].sqlite` | Synced devices |

## ZDEVICE Table Schema

```sql
CREATE TABLE ZDEVICE (
    ZIDENTIFIER TEXT PRIMARY KEY,   -- Unique device ID
    ZNAME TEXT,                     -- Device name (e.g., "John's Mac")
    ZMODEL TEXT,                    -- Model type (Mac, iPhone, iPad)
    ZLASTSEENDATE REAL,             -- Last seen (Core Data timestamp)
    ...
);
```

## DeviceInfo Swift Model

```swift
struct DeviceInfo: Identifiable, Codable, Hashable {
    let id: String                  // Device identifier
    let name: String                // Friendly name
    let model: String               // Device model
    let lastSeen: Date              // Last usage
}
```

## Core Data Timestamp Conversion

```swift
// Convert FROM Core Data TO Swift Date
let referenceDate = Date(timeIntervalSinceReferenceDate: 0)  // 2001-01-01
let swiftDate = Date(timeInterval: coreDataTimestamp, since: referenceDate)

// Convert FROM Swift Date TO Core Data
let coreDataTimestamp = swiftDate.timeIntervalSince(referenceDate)
```

## Key Methods

### DatabaseManager.fetchDevices()
```swift
// Reads ZDEVICE table from all .sqlite files in com.apple.screentime/
// Deduplicates by device ID
// Returns sorted array of DeviceInfo
func fetchDevices() throws -> [DeviceInfo]
```

### ScreenTimeDataManager.loadDevices()
```swift
// Called at app launch
// Populates @Published var devices: [DeviceInfo]
// Auto-selects first device
func loadDevices()
```

### ScreenTimeDataManager.refreshData()
```swift
// Called when device selection changes
// Fetches usage for selected device
// Updates @Published var currentUsage: [AppUsage]
func refreshData()
```

## ZOBJECT Table (App Usage Events)

```sql
CREATE TABLE ZOBJECT (
    Z_PK INTEGER PRIMARY KEY,
    ZSTREAMNAME TEXT,               -- "/app/usage", "/app/inFocus"
    ZSTARTDATE REAL,                -- Event start (Core Data timestamp)
    ZENDDATE REAL,                  -- Event end (optional)
    ZVALUESTRING TEXT,              -- App bundle ID
    ...
);
```

## Data Flow Diagram

```
User Launches App
       │
       ↓
ScreenTimeDataManager.init()
       │
       ├─ checkPermissions()
       │
       └─ loadDevices()
              │
              ↓
          DatabaseManager.fetchDevices()
              │
              ├─ Scan ~/Library/Application Support/com.apple.screentime/
              │
              ├─ Find all .sqlite files
              │
              ├─ For each file:
              │   └─ Read ZDEVICE table
              │
              └─ Deduplicate & return [DeviceInfo]
                     │
                     ↓
         @Published var devices: [DeviceInfo]
                     │
                     ↓
          User selects device in UI
                     │
                     ↓
       @Published var selectedDevice: DeviceInfo?
                     │
                     ↓
            refreshData() triggered
                     │
                     ↓
         DatabaseManager.fetchAppUsage()
                     │
                     ├─ Query ZOBJECT from knowledgeC.db
                     │
                     ├─ Filter by date range
                     │
                     └─ Return [AppUsage]
                            │
                            ↓
              @Published var currentUsage: [AppUsage]
                            │
                            ↓
                      UI updates with charts
```

## Common Queries

### Get All Devices
```swift
let devices = ScreenTimeDataManager.shared.devices
```

### Get Usage for Selected Device
```swift
let selectedDevice = ScreenTimeDataManager.shared.selectedDevice
let usage = ScreenTimeDataManager.shared.currentUsage
```

### Get Device Breakdown
```swift
if let summary = ScreenTimeDataManager.shared.usageSummary {
    let breakdown = summary.deviceBreakdown  // [String: TimeInterval]
}
```

### Filter Usage by Device
```swift
let usage = try DatabaseManager.shared.fetchAppUsage(
    from: startDate,
    to: endDate
)
let deviceUsage = usage.filter { $0.deviceIdentifier == device.id }
```

## File Locations in Project

| File | Purpose |
|------|---------|
| `AppUsage.swift` | DeviceInfo struct definition |
| `DatabaseManager.swift` | Database queries (fetchDevices, fetchAppUsage) |
| `ScreenTimeDataManager.swift` | Published properties, data loading |
| `ContentView.swift` | Main UI view |
| `AppListView.swift` | Device/app list display |
| `UsageChartView.swift` | Chart visualization |

## Permission Requirements

- **Full Disk Access**: Required to read Screen Time databases
- **Check**: `DatabaseManager.checkDatabaseAccess()` returns `true/false`
- **Request**: `ScreenTimeDataManager.requestFullDiskAccess()`

## Error Handling

### No devices found
- Returns fallback: current device
- Log: "No devices found in databases, returning current device"

### ZDEVICE table missing
- Skips database file
- Log: "No ZDEVICE table in [filename]"

### Directory not accessible
- Returns fallback: current device
- Log: "Screen Time directory not found"

## Debugging Tips

1. Check console output:
   ```
   🔍 Scanning Screen Time directory...
   📁 Found X database files
   ✅ Successfully read N device(s)
   📱 Total unique devices found: X
   ```

2. Verify database exists:
   ```bash
   ls -la ~/Library/Application\ Support/com.apple.screentime/
   ```

3. Check database with sqlite3:
   ```bash
   sqlite3 ~/Library/Application\ Support/com.apple.screentime/RMAdminStore-Local.sqlite
   sqlite> SELECT * FROM ZDEVICE;
   ```

4. Check app logs in Xcode Console

## Recent Changes (Commit 0dd719f)

**What Changed**:
- Now scans ALL .sqlite files (not just RMAdminStore-Local.sqlite)
- Deduplicates devices by ID
- Includes lastSeen timestamp
- Better error handling

**Why**: To detect iCloud-synced devices from iPhone/iPad

## Current Limitations

1. **Data Retention**: Only ~28 days of detailed data
2. **Device Discovery**: Only shows devices with app usage
3. **Timestamp Resolution**: Core Data epoch (2001-01-01)
4. **Database Locks**: Can't write to protected databases

## Performance Considerations

- Device fetch: < 100ms (usually)
- App usage fetch: 200-500ms depending on date range
- Deduplication: O(n) where n = devices found
- Database scans: File I/O bound
