# Device API Usage Examples

## Accessing Devices in Views

### Example 1: Device Picker (ContentView)
```swift
@EnvironmentObject var dataManager: ScreenTimeDataManager

// In your view:
Picker("Device", selection: $dataManager.selectedDevice) {
    Text("All Devices").tag(nil as DeviceInfo?)
    ForEach(dataManager.devices) { device in
        Text(device.name).tag(device as DeviceInfo?)
    }
}
```

**What happens**:
1. User selects device from picker
2. `selectedDevice` property updates
3. Triggers `$selectedDevice.sink` in ScreenTimeDataManager
4. Calls `refreshData()` 
5. Fetches usage for selected device
6. UI automatically updates with new data

### Example 2: Display Selected Device Info
```swift
import SwiftUI

struct DeviceDetailView: View {
    @EnvironmentObject var dataManager: ScreenTimeDataManager
    
    var body: some View {
        if let device = dataManager.selectedDevice {
            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Model: \(device.model)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Last Seen: \(device.lastSeen.formatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        } else {
            Text("No device selected")
        }
    }
}
```

### Example 3: List All Available Devices
```swift
struct DeviceListView: View {
    @EnvironmentObject var dataManager: ScreenTimeDataManager
    
    var body: some View {
        List {
            Section("Available Devices") {
                ForEach(dataManager.devices) { device in
                    VStack(alignment: .leading) {
                        Text(device.name)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text("Model: \(device.model)")
                            Spacer()
                            Text(device.lastSeen.formatted(date: .omitted, time: .shortened))
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
```

### Example 4: Device Breakdown Chart
```swift
struct DeviceBreakdownView: View {
    @EnvironmentObject var dataManager: ScreenTimeDataManager
    
    var body: some View {
        if let summary = dataManager.usageSummary {
            VStack(alignment: .leading) {
                Text("Usage by Device")
                    .font(.headline)
                
                ForEach(summary.deviceBreakdown.sorted(by: { $0.value > $1.value }), 
                        id: \.key) { deviceId, totalTime in
                    HStack {
                        // Find device name
                        let deviceName = dataManager.devices
                            .first { $0.id == deviceId }?.name ?? "Unknown"
                        
                        Text(deviceName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(dataManager.formatDuration(totalTime))
                            .fontWeight(.bold)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
        }
    }
}
```

## Direct DatabaseManager Usage

### Example 5: Query App Usage for Specific Device
```swift
import Foundation

func getUsageForDevice(_ deviceId: String, from: Date, to: Date) throws {
    let dbManager = DatabaseManager.shared
    
    // Fetch all usage
    let allUsage = try dbManager.fetchAppUsage(from: from, to: to)
    
    // Filter by device
    let deviceUsage = allUsage.filter { $0.deviceIdentifier == deviceId }
    
    // Calculate total
    let totalTime = deviceUsage.reduce(0) { $0 + $1.totalTime }
    
    print("Device \(deviceId) usage: \(formatTime(totalTime))")
    
    // Top apps for device
    let topApps = deviceUsage
        .sorted { $0.totalTime > $1.totalTime }
        .prefix(5)
    
    for app in topApps {
        print("- \(app.appName): \(formatTime(app.totalTime))")
    }
}
```

### Example 6: Load Devices Programmatically
```swift
func loadAndDisplayDevices() {
    Task {
        do {
            let devices = try DatabaseManager.shared.fetchDevices()
            
            for device in devices {
                print("Device: \(device.name)")
                print("  ID: \(device.id)")
                print("  Model: \(device.model)")
                print("  Last Seen: \(device.lastSeen)")
            }
        } catch {
            print("Error loading devices: \(error)")
        }
    }
}
```

### Example 7: Watch Device Selection Changes
```swift
@StateObject var dataManager = ScreenTimeDataManager.shared

func setupDeviceObserver() {
    dataManager.$selectedDevice
        .sink { newDevice in
            if let device = newDevice {
                print("Selected device changed to: \(device.name)")
                // Update UI, refresh data, etc.
            }
        }
        .store(in: &cancellables)
}
```

## Data Model Usage

### Example 8: Create DeviceInfo Programmatically
```swift
// Create a new device info object
let device = DeviceInfo(
    id: "UUID-12345",
    name: "John's iPhone",
    model: "iPhone",
    lastSeen: Date()
)

// Use it
print("Device: \(device.name) (\(device.model))")
```

### Example 9: Compare Devices
```swift
let device1 = DeviceInfo(id: "id1", name: "Mac", model: "Mac")
let device2 = DeviceInfo(id: "id2", name: "iPhone", model: "iPhone")

// DeviceInfo conforms to Hashable
let deviceSet: Set<DeviceInfo> = [device1, device2]

// DeviceInfo conforms to Identifiable
let deviceArray = [device1, device2]
ForEach(deviceArray) { device in
    Text(device.name)
}
```

## Real-World Scenarios

### Scenario 1: Compare Usage Across Devices
```swift
func compareDeviceUsage(for apps: [String]) throws {
    let dbManager = DatabaseManager.shared
    let devices = try dbManager.fetchDevices()
    
    let today = Date()
    let startOfDay = Calendar.current.startOfDay(for: today)
    
    // Get usage for each device
    var deviceComparison: [String: [String: TimeInterval]] = [:]
    
    for device in devices {
        let usage = try dbManager.fetchAppUsage(from: startOfDay, to: today)
        let deviceUsage = usage.filter { $0.deviceIdentifier == device.id }
        
        var appTimes: [String: TimeInterval] = [:]
        for app in apps {
            appTimes[app] = deviceUsage
                .filter { $0.bundleIdentifier == app }
                .reduce(0) { $0 + $1.totalTime }
        }
        
        deviceComparison[device.name] = appTimes
    }
    
    // Print comparison
    for (deviceName, appTimes) in deviceComparison {
        print("\(deviceName):")
        for (app, time) in appTimes {
            print("  \(app): \(formatTime(time))")
        }
    }
}
```

### Scenario 2: Find Most Used Device
```swift
func findMostUsedDevice(from: Date, to: Date) throws -> DeviceInfo? {
    let dbManager = DatabaseManager.shared
    let devices = try dbManager.fetchDevices()
    
    var deviceUsageTotals: [DeviceInfo: TimeInterval] = [:]
    
    let allUsage = try dbManager.fetchAppUsage(from: from, to: to)
    
    for device in devices {
        let deviceUsage = allUsage.filter { $0.deviceIdentifier == device.id }
        let total = deviceUsage.reduce(0) { $0 + $1.totalTime }
        deviceUsageTotals[device] = total
    }
    
    return deviceUsageTotals.max(by: { $0.value < $1.value })?.key
}
```

### Scenario 3: Export Device Usage Report
```swift
func exportDeviceReport() throws {
    let dbManager = DatabaseManager.shared
    let devices = try dbManager.fetchDevices()
    
    var reportLines: [String] = [
        "Device Usage Report",
        "===================",
        ""
    ]
    
    let today = Date()
    let last7Days = Calendar.current.date(byAdding: .day, value: -7, to: today)!
    
    for device in devices {
        reportLines.append("Device: \(device.name)")
        reportLines.append("Model: \(device.model)")
        reportLines.append("ID: \(device.id)")
        reportLines.append("Last Seen: \(device.lastSeen.formatted())")
        
        let usage = try dbManager.fetchAppUsage(from: last7Days, to: today)
        let deviceUsage = usage.filter { $0.deviceIdentifier == device.id }
        let total = deviceUsage.reduce(0) { $0 + $1.totalTime }
        
        reportLines.append("Total Usage (7 days): \(formatTime(total))")
        reportLines.append("Top Apps:")
        
        for app in deviceUsage.prefix(5) {
            reportLines.append("  - \(app.appName): \(formatTime(app.totalTime))")
        }
        
        reportLines.append("")
    }
    
    let report = reportLines.joined(separator: "\n")
    // Save report to file or share
    print(report)
}
```

## Testing Examples

### Example 10: Mock Device Data for Testing
```swift
import XCTest

class DeviceTests: XCTestCase {
    func testDeviceCreation() {
        let device = DeviceInfo(
            id: "test-123",
            name: "Test Device",
            model: "Mac",
            lastSeen: Date()
        )
        
        XCTAssertEqual(device.id, "test-123")
        XCTAssertEqual(device.name, "Test Device")
        XCTAssertEqual(device.model, "Mac")
    }
    
    func testDeviceHashable() {
        let device1 = DeviceInfo(id: "id1", name: "Device 1", model: "Mac")
        let device2 = DeviceInfo(id: "id1", name: "Device 1", model: "Mac")
        
        // Same ID = same device
        XCTAssertEqual(device1, device2)
    }
    
    func testDeviceCodable() throws {
        let device = DeviceInfo(id: "id1", name: "Device 1", model: "Mac")
        
        let encoded = try JSONEncoder().encode(device)
        let decoded = try JSONDecoder().decode(DeviceInfo.self, from: encoded)
        
        XCTAssertEqual(device, decoded)
    }
}
```

## Common Patterns

### Pattern 1: Device Selection with Fallback
```swift
let targetDevice = dataManager.selectedDevice ?? dataManager.devices.first
if let device = targetDevice {
    // Use device
}
```

### Pattern 2: Safe Device Lookup
```swift
func getDevice(byId id: String) -> DeviceInfo? {
    return dataManager.devices.first { $0.id == id }
}
```

### Pattern 3: Device Change Handler
```swift
dataManager.$selectedDevice
    .dropFirst()  // Skip initial value
    .sink { newDevice in
        if let device = newDevice {
            print("User selected: \(device.name)")
            // Handle selection change
        } else {
            print("User selected: All Devices")
        }
    }
    .store(in: &cancellables)
```

### Pattern 4: Async Device Loading
```swift
Task {
    do {
        let devices = try DatabaseManager.shared.fetchDevices()
        await MainActor.run {
            // Update UI on main thread
            self.displayedDevices = devices
        }
    } catch {
        await MainActor.run {
            self.errorMessage = "Failed to load devices: \(error)"
        }
    }
}
```
