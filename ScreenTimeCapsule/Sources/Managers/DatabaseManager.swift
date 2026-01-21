import Foundation
import AppKit
import IOKit
import SQLite

class DatabaseManager {
    static let shared = DatabaseManager()

    private let fileManager = FileManager.default

    private var knowledgeDBPath: String {
        // Expand ~ to get the real user home directory, bypassing sandbox container
        return NSString(string: "~/Library/Application Support/Knowledge/knowledgeC.db").expandingTildeInPath
    }

    private var screenTimeDBPath: String {
        // Expand ~ to get the real user home directory, bypassing sandbox container
        return NSString(string: "~/Library/Application Support/com.apple.screentime/RMAdminStore-Local.sqlite").expandingTildeInPath
    }

    private var screenTimeDirectory: String {
        return NSString(string: "~/Library/Application Support/com.apple.screentime").expandingTildeInPath
    }

    private init() {}

    // MARK: - Database Access Check

    func checkDatabaseAccess() -> Bool {
        // Check if files exist first
        let knowledgeExists = fileManager.fileExists(atPath: knowledgeDBPath)
        let screenTimeExists = fileManager.fileExists(atPath: screenTimeDBPath)

        print("Knowledge DB path: \(knowledgeDBPath)")
        print("Knowledge DB exists: \(knowledgeExists)")
        print("Screen Time DB path: \(screenTimeDBPath)")
        print("Screen Time DB exists: \(screenTimeExists)")

        // If neither exists, user might not have Screen Time enabled
        guard knowledgeExists || screenTimeExists else {
            print("No Screen Time databases found")
            return false
        }

        // Try to read the file to verify Full Disk Access
        // Just checking existence isn't enough - we need actual read permission
        if knowledgeExists {
            do {
                // Try to open and read the database
                let db = try Connection(knowledgeDBPath, readonly: true)
                _ = try db.scalar("SELECT COUNT(*) FROM sqlite_master") as? Int64
                print("✅ Successfully accessed Knowledge database")
                return true
            } catch {
                print("❌ Database access error: \(error)")
                print("   This usually means Full Disk Access is not granted")
                return false
            }
        }

        // Fallback: try Screen Time database if knowledge DB doesn't exist
        if screenTimeExists {
            do {
                let db = try Connection(screenTimeDBPath, readonly: true)
                _ = try db.scalar("SELECT COUNT(*) FROM sqlite_master") as? Int64
                print("✅ Successfully accessed Screen Time database")
                return true
            } catch {
                print("❌ Database access error: \(error)")
                return false
            }
        }

        return false
    }

    // MARK: - Fetch App Usage Data

    func fetchAppUsage(from startDate: Date, to endDate: Date, deviceId: String? = nil) throws -> [AppUsage] {
        print("🔍 fetchAppUsage() called for range: \(startDate) to \(endDate)")
        if let deviceId = deviceId {
            print("🔍 Filtering by device: \(deviceId)")
        }

        let db = try Connection(knowledgeDBPath, readonly: true)

        // Define table and columns based on knowledgeC.db schema
        let objects = Table("ZOBJECT")
        let zId = Expression<Int64>("Z_PK")
        let zStreamName = Expression<String?>("ZSTREAMNAME")
        let zStartDate = Expression<Double>("ZSTARTDATE")
        let zEndDate = Expression<Double?>("ZENDDATE")
        let zValueString = Expression<String?>("ZVALUESTRING")

        let metadata = Table("ZSTRUCTUREDMETADATA")
        let zIdentifier = Expression<String?>("ZIDENTIFIER")
        let zTitle = Expression<String?>("ZTITLE")

        var appUsageMap: [String: (name: String, totalTime: TimeInterval)] = [:]

        // Query app usage events
        // knowledgeC uses Core Data timestamp (seconds since 2001-01-01)
        let referenceDate = Date(timeIntervalSinceReferenceDate: 0)
        let startTimestamp = startDate.timeIntervalSince(referenceDate)
        let endTimestamp = endDate.timeIntervalSince(referenceDate)

        print("🔍 Querying with timestamps: \(startTimestamp) to \(endTimestamp)")

        // First, check what stream names exist in the database
        let allStreamsQuery = try db.prepare("SELECT DISTINCT ZSTREAMNAME FROM ZOBJECT WHERE ZSTREAMNAME IS NOT NULL LIMIT 20")
        print("🔍 Available stream names in database:")
        for row in allStreamsQuery {
            if let streamName = row[0] as? String {
                print("   - \(streamName)")
            }
        }

        // Use raw SQL for better control over joins and filtering
        var sql = """
            SELECT o.ZSTARTDATE, o.ZENDDATE, o.ZVALUESTRING
            FROM ZOBJECT o
            """

        // Add device filtering if deviceId is provided
        if let deviceId = deviceId {
            sql += """
                LEFT JOIN ZSOURCE s ON o.ZSOURCE = s.Z_PK
                WHERE (o.ZSTREAMNAME = '/app/usage' OR o.ZSTREAMNAME = '/app/inFocus')
                AND o.ZSTARTDATE >= ?
                AND o.ZSTARTDATE <= ?
                AND (s.ZDEVICEID = ? OR s.ZSOURCEID = ?)
                """
        } else {
            sql += """
                WHERE (o.ZSTREAMNAME = '/app/usage' OR o.ZSTREAMNAME = '/app/inFocus')
                AND o.ZSTARTDATE >= ?
                AND o.ZSTARTDATE <= ?
                """
        }

        var rowCount = 0
        var skippedCount = 0
        var eventsWithoutEndDate = 0

        let rows: Statement
        if let deviceId = deviceId {
            rows = try db.prepare(sql, startTimestamp, endTimestamp, deviceId, deviceId)
        } else {
            rows = try db.prepare(sql, startTimestamp, endTimestamp)
        }

        for row in rows {
            rowCount += 1

            // Handle both Int64 and Double types from database for timestamps
            let eventStartTimestamp: Double
            if let intVal = row[0] as? Int64 {
                eventStartTimestamp = Double(intVal)
            } else if let doubleVal = row[0] as? Double {
                eventStartTimestamp = doubleVal
            } else {
                continue
            }

            guard let bundleId = row[2] as? String else {
                skippedCount += 1
                continue
            }

            // Log first few rows for debugging
            if rowCount <= 3 {
                print("🔍 Row \(rowCount): bundleId=\(bundleId), hasEndDate=\(row[1] != nil)")
            }

            // Calculate duration
            let duration: Double
            if let endInt = row[1] as? Int64 {
                duration = Double(endInt) - eventStartTimestamp
            } else if let endDouble = row[1] as? Double {
                duration = endDouble - eventStartTimestamp
            } else {
                // No end date - use default duration of 60 seconds per event
                duration = 60.0
                eventsWithoutEndDate += 1
            }

            if var existing = appUsageMap[bundleId] {
                existing.totalTime += duration
                appUsageMap[bundleId] = existing
            } else {
                let appName = extractAppName(from: bundleId)
                appUsageMap[bundleId] = (name: appName, totalTime: duration)
            }
        }

        print("🔍 Skipped \(skippedCount) rows due to missing bundleId")
        print("🔍 Events without endDate (using 60s default): \(eventsWithoutEndDate)")

        print("🔍 Processed \(rowCount) database rows")
        print("🔍 Found \(appUsageMap.count) unique apps")

        // Convert to AppUsage objects
        let usageArray = appUsageMap.map { bundleId, info in
            AppUsage(
                bundleIdentifier: bundleId,
                appName: info.name,
                totalTime: info.totalTime,
                startDate: startDate,
                endDate: endDate,
                category: categorizeApp(bundleId: bundleId)
            )
        }.sorted { $0.totalTime > $1.totalTime }

        return usageArray
    }

    // MARK: - Fetch Hourly App Usage Events

    func fetchHourlyAppUsageEvents(from startDate: Date, to endDate: Date, deviceId: String? = nil) throws -> [(hour: Int, category: UsageCategory, usage: TimeInterval)] {
        print("🔍 fetchHourlyAppUsageEvents() called for range: \(startDate) to \(endDate)")
        if let deviceId = deviceId {
            print("🔍 Filtering by device: \(deviceId)")
        }

        let db = try Connection(knowledgeDBPath, readonly: true)

        let referenceDate = Date(timeIntervalSinceReferenceDate: 0)
        let startTimestamp = startDate.timeIntervalSince(referenceDate)
        let endTimestamp = endDate.timeIntervalSince(referenceDate)

        // Storage for hourly data by category
        var hourlyData: [Int: [UsageCategory: TimeInterval]] = [:]
        let calendar = Calendar.current

        // Use raw SQL with optional device filtering
        var sql = """
            SELECT o.ZSTARTDATE, o.ZENDDATE, o.ZVALUESTRING
            FROM ZOBJECT o
            """

        if let deviceId = deviceId {
            sql += """
                LEFT JOIN ZSOURCE s ON o.ZSOURCE = s.Z_PK
                WHERE (o.ZSTREAMNAME = '/app/usage' OR o.ZSTREAMNAME = '/app/inFocus')
                AND o.ZSTARTDATE IS NOT NULL
                AND o.ZSTARTDATE >= ?
                AND o.ZSTARTDATE <= ?
                AND (s.ZDEVICEID = ? OR s.ZSOURCEID = ?)
                """
        } else {
            sql += """
                WHERE (o.ZSTREAMNAME = '/app/usage' OR o.ZSTREAMNAME = '/app/inFocus')
                AND o.ZSTARTDATE IS NOT NULL
                AND o.ZSTARTDATE >= ?
                AND o.ZSTARTDATE <= ?
                """
        }

        var eventCount = 0

        let rows: Statement
        if let deviceId = deviceId {
            rows = try db.prepare(sql, startTimestamp, endTimestamp, deviceId, deviceId)
        } else {
            rows = try db.prepare(sql, startTimestamp, endTimestamp)
        }

        for row in rows {
            guard let bundleId = row[2] as? String else { continue }

            // Handle both Int64 and Double types from database
            let eventStartTimestamp: Double
            if let intVal = row[0] as? Int64 {
                eventStartTimestamp = Double(intVal)
            } else if let doubleVal = row[0] as? Double {
                eventStartTimestamp = doubleVal
            } else {
                continue
            }

            // Calculate duration
            let duration: Double
            if let endInt = row[1] as? Int64 {
                duration = Double(endInt) - eventStartTimestamp
            } else if let endDouble = row[1] as? Double {
                duration = endDouble - eventStartTimestamp
            } else {
                duration = 60.0 // Default 1 minute for events without end date
            }

            // Get the actual event timestamp
            let eventDate = Date(timeInterval: eventStartTimestamp, since: referenceDate)
            let hour = calendar.component(.hour, from: eventDate)

            // Categorize the app
            let category = categorizeApp(bundleId: bundleId)

            // Add to hourly data
            if hourlyData[hour] == nil {
                hourlyData[hour] = [:]
            }
            hourlyData[hour]![category, default: 0] += duration

            eventCount += 1
        }

        print("🔍 Processed \(eventCount) events for hourly breakdown")

        // Convert to result format
        var result: [(hour: Int, category: UsageCategory, usage: TimeInterval)] = []
        for hour in 0...23 {
            if let categoryData = hourlyData[hour] {
                // Sort by category sortOrder for proper stacking (bottom to top)
                for (category, usage) in categoryData.sorted(by: { $0.key.sortOrder < $1.key.sortOrder }) {
                    result.append((hour: hour, category: category, usage: usage))
                }
            }
        }

        return result
    }

    // MARK: - Fetch Daily App Usage Events

    func fetchDailyAppUsageEvents(from startDate: Date, to endDate: Date, deviceId: String? = nil) throws -> [(day: String, category: UsageCategory, usage: TimeInterval)] {
        print("🔍 fetchDailyAppUsageEvents() called for range: \(startDate) to \(endDate)")
        if let deviceId = deviceId {
            print("🔍 Filtering by device: \(deviceId)")
        }

        let db = try Connection(knowledgeDBPath, readonly: true)

        let referenceDate = Date(timeIntervalSinceReferenceDate: 0)
        let startTimestamp = startDate.timeIntervalSince(referenceDate)
        let endTimestamp = endDate.timeIntervalSince(referenceDate)

        let calendar = Calendar.current
        let daysDiff = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = daysDiff <= 7 ? "E" : "MMM d" // "Mon" or "Jan 15"

        // Storage for daily data by actual date (not formatted string)
        // This prevents duplicate weekday names from colliding
        var dailyData: [Date: [UsageCategory: TimeInterval]] = [:]

        // Use raw SQL with optional device filtering
        var sql = """
            SELECT o.ZSTARTDATE, o.ZENDDATE, o.ZVALUESTRING
            FROM ZOBJECT o
            """

        if let deviceId = deviceId {
            sql += """
                LEFT JOIN ZSOURCE s ON o.ZSOURCE = s.Z_PK
                WHERE (o.ZSTREAMNAME = '/app/usage' OR o.ZSTREAMNAME = '/app/inFocus')
                AND o.ZSTARTDATE IS NOT NULL
                AND o.ZSTARTDATE >= ?
                AND o.ZSTARTDATE <= ?
                AND (s.ZDEVICEID = ? OR s.ZSOURCEID = ?)
                """
        } else {
            sql += """
                WHERE (o.ZSTREAMNAME = '/app/usage' OR o.ZSTREAMNAME = '/app/inFocus')
                AND o.ZSTARTDATE IS NOT NULL
                AND o.ZSTARTDATE >= ?
                AND o.ZSTARTDATE <= ?
                """
        }

        var eventCount = 0

        let rows: Statement
        if let deviceId = deviceId {
            rows = try db.prepare(sql, startTimestamp, endTimestamp, deviceId, deviceId)
        } else {
            rows = try db.prepare(sql, startTimestamp, endTimestamp)
        }

        for row in rows {
            guard let bundleId = row[2] as? String else { continue }

            // Handle both Int64 and Double types from database
            let eventStartTimestamp: Double
            if let intVal = row[0] as? Int64 {
                eventStartTimestamp = Double(intVal)
            } else if let doubleVal = row[0] as? Double {
                eventStartTimestamp = doubleVal
            } else {
                continue
            }

            // Calculate duration
            let duration: Double
            if let endInt = row[1] as? Int64 {
                duration = Double(endInt) - eventStartTimestamp
            } else if let endDouble = row[1] as? Double {
                duration = endDouble - eventStartTimestamp
            } else {
                duration = 60.0 // Default 1 minute for events without end date
            }

            // Get the actual event timestamp
            let eventDate = Date(timeInterval: eventStartTimestamp, since: referenceDate)
            let dayStart = calendar.startOfDay(for: eventDate)

            // Categorize the app
            let category = categorizeApp(bundleId: bundleId)

            // Add to daily data using actual Date as key
            if dailyData[dayStart] == nil {
                dailyData[dayStart] = [:]
            }
            dailyData[dayStart]![category, default: 0] += duration

            eventCount += 1
        }

        print("🔍 Processed \(eventCount) events for daily breakdown")
        print("🔍 Found \(dailyData.keys.count) unique days")

        // Convert to result format, maintaining chronological order
        var result: [(day: String, category: UsageCategory, usage: TimeInterval)] = []

        // Sort dates chronologically
        let sortedDates = dailyData.keys.sorted()

        for dayStart in sortedDates {
            let dayLabel = dateFormatter.string(from: dayStart)

            if let categoryData = dailyData[dayStart] {
                print("🔍 Day: \(dayLabel) (\(dayStart)) - Categories: \(categoryData.keys.count)")
                // Sort by category sortOrder for proper stacking (bottom to top)
                for (category, usage) in categoryData.sorted(by: { $0.key.sortOrder < $1.key.sortOrder }) {
                    result.append((day: dayLabel, category: category, usage: usage))
                }
            }
        }

        return result
    }

    // MARK: - Fetch Devices

    func fetchDevices() throws -> [DeviceInfo] {
        var allDevices: [String: DeviceInfo] = [:] // Use dictionary to deduplicate by device ID

        // Try to get devices from Screen Time directory first
        if fileManager.fileExists(atPath: screenTimeDirectory) {
            print("🔍 Scanning Screen Time directory: \(screenTimeDirectory)")

            // Get all files in the Screen Time directory
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: screenTimeDirectory)
                let sqliteFiles = contents.filter { $0.hasSuffix(".sqlite") }

                print("📁 Found \(sqliteFiles.count) database files:")
                for file in sqliteFiles {
                    print("   - \(file)")
                }

                // Try to read devices from each database file
                for filename in sqliteFiles {
                    let dbPath = (screenTimeDirectory as NSString).appendingPathComponent(filename)

                    do {
                        let db = try Connection(dbPath, readonly: true)
                        let devices = try fetchDevicesFromScreenTimeDB(db: db, source: filename)

                        // Add devices to our collection (deduplicating by ID)
                        for device in devices {
                            allDevices[device.id] = device
                        }

                        print("✅ Successfully read \(devices.count) device(s) from \(filename)")
                    } catch {
                        print("⚠️ Could not read devices from \(filename): \(error)")
                        // Continue to next database file
                        continue
                    }
                }
            } catch {
                print("❌ Error reading Screen Time directory: \(error)")
            }
        } else {
            print("⚠️ Screen Time directory not found: \(screenTimeDirectory)")
        }

        // If no devices found from Screen Time, try Knowledge database
        if allDevices.isEmpty {
            print("🔍 Attempting to extract devices from Knowledge database")
            do {
                let knowledgeDevices = try fetchDevicesFromKnowledgeDB()
                for device in knowledgeDevices {
                    allDevices[device.id] = device
                }
                print("✅ Found \(knowledgeDevices.count) device(s) from Knowledge database")
            } catch {
                print("⚠️ Could not extract devices from Knowledge database: \(error)")
            }
        }

        // If we found devices, return them
        if !allDevices.isEmpty {
            print("📱 Total unique devices found: \(allDevices.count)")
            return Array(allDevices.values).sorted { $0.name < $1.name }
        }

        // Fallback: return current device
        print("⚠️ No devices found in databases, returning current device")
        return [DeviceInfo(
            id: getCurrentDeviceID(),
            name: Host.current().localizedName ?? "This Mac",
            model: "Mac"
        )]
    }

    private func fetchDevicesFromScreenTimeDB(db: Connection, source: String) throws -> [DeviceInfo] {
        var deviceList: [DeviceInfo] = []

        // Try to fetch devices from ZDEVICE table
        do {
            let devices = Table("ZDEVICE")
            let zId = Expression<String>("ZIDENTIFIER")
            let zName = Expression<String?>("ZNAME")
            let zModel = Expression<String?>("ZMODEL")
            let zLastSeen = Expression<Double?>("ZLASTSEENDATE")

            for row in try db.prepare(devices) {
                // Convert Core Data timestamp to Date if available
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

            print("   ℹ️ Read \(deviceList.count) devices from ZDEVICE table in \(source)")
        } catch {
            // Table might not exist in this database
            print("   ℹ️ No ZDEVICE table in \(source): \(error)")
        }

        return deviceList
    }

    private func fetchDevicesFromKnowledgeDB() throws -> [DeviceInfo] {
        var deviceList: [DeviceInfo] = []
        var deviceMap: [String: DeviceInfo] = [:]

        guard fileManager.fileExists(atPath: knowledgeDBPath) else {
            print("   ℹ️ Knowledge database not found")
            return deviceList
        }

        let db = try Connection(knowledgeDBPath, readonly: true)

        // Try to fetch from ZSOURCE table which contains device information
        do {
            let sources = Table("ZSOURCE")
            let zDeviceId = Expression<String?>("ZDEVICEID")
            let zSourceId = Expression<String?>("ZSOURCEID")
            let zBundleId = Expression<String?>("ZBUNDLEID")

            for row in try db.prepare(sources) {
                // Try to get device ID from various fields
                var deviceId: String? = row[zDeviceId] ?? row[zSourceId]

                // Skip if no device ID found
                guard let devId = deviceId, !devId.isEmpty else { continue }

                // Only add if not already in our map
                if deviceMap[devId] == nil {
                    // Try to get a friendly name from the bundle ID or use device ID
                    let name: String
                    if let bundleId = row[zBundleId], !bundleId.isEmpty {
                        // Extract app name from bundle ID as a hint for device type
                        name = devId.prefix(8).uppercased() + " Device"
                    } else {
                        name = devId.prefix(8).uppercased() + " Device"
                    }

                    deviceMap[devId] = DeviceInfo(
                        id: devId,
                        name: name,
                        model: "Unknown"
                    )
                }
            }

            print("   ℹ️ Read \(deviceMap.count) unique devices from ZSOURCE table")
        } catch {
            print("   ℹ️ Could not read ZSOURCE table: \(error)")
        }

        // If ZSOURCE didn't work, try extracting device IDs from sync stream names
        if deviceMap.isEmpty {
            do {
                let sql = """
                    SELECT DISTINCT ZSTREAMNAME
                    FROM ZOBJECT
                    WHERE ZSTREAMNAME LIKE '/knowledge-sync-%'
                    LIMIT 100
                """

                var syncDeviceIds = Set<String>()
                for row in try db.prepare(sql) {
                    if let streamName = row[0] as? String {
                        // Extract UUID from stream names like "/knowledge-sync-addition-window/UUID"
                        let components = streamName.split(separator: "/")
                        if components.count >= 3,
                           let uuid = components.last,
                           uuid.count == 36 { // UUID format check
                            syncDeviceIds.insert(String(uuid))
                        }
                    }
                }

                for deviceId in syncDeviceIds {
                    let shortId = deviceId.prefix(8).uppercased()
                    deviceMap[deviceId] = DeviceInfo(
                        id: deviceId,
                        name: "\(shortId) Device",
                        model: "Unknown"
                    )
                }

                print("   ℹ️ Extracted \(deviceMap.count) device IDs from sync streams")
            } catch {
                print("   ℹ️ Could not extract device IDs from sync streams: \(error)")
            }
        }

        return Array(deviceMap.values)
    }

    // MARK: - Helper Methods

    private func extractAppName(from bundleId: String) -> String {
        // Try to get app name from bundle
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: appURL),
           let name = bundle.infoDictionary?["CFBundleName"] as? String {
            return name
        }

        // Fallback: extract from bundle ID
        let components = bundleId.split(separator: ".")
        return components.last.map(String.init)?.capitalized ?? bundleId
    }

    private func categorizeApp(bundleId: String) -> UsageCategory {
        let lowerBundleId = bundleId.lowercased()

        // Productivity: Development tools, office apps, finance
        if lowerBundleId.contains("xcode") || lowerBundleId.contains("vscode") ||
           lowerBundleId.contains("sublime") || lowerBundleId.contains("atom") ||
           lowerBundleId.contains("finance") || lowerBundleId.contains("numbers") ||
           lowerBundleId.contains("excel") || lowerBundleId.contains("word") ||
           lowerBundleId.contains("pages") || lowerBundleId.contains("keynote") {
            return .productivity
        }

        // Creativity: Design, photo/video editing, music production
        else if lowerBundleId.contains("photoshop") || lowerBundleId.contains("illustrator") ||
                lowerBundleId.contains("sketch") || lowerBundleId.contains("figma") ||
                lowerBundleId.contains("finalcut") || lowerBundleId.contains("logic") ||
                lowerBundleId.contains("garageband") || lowerBundleId.contains("premiere") {
            return .creativity
        }

        // Social: Messaging and social media
        else if lowerBundleId.contains("message") || lowerBundleId.contains("slack") ||
                lowerBundleId.contains("discord") || lowerBundleId.contains("twitter") ||
                lowerBundleId.contains("facebook") || lowerBundleId.contains("instagram") ||
                lowerBundleId.contains("whatsapp") || lowerBundleId.contains("telegram") {
            return .social
        }

        // Entertainment: Media consumption and games
        else if lowerBundleId.contains("music") || lowerBundleId.contains("spotify") ||
                lowerBundleId.contains("netflix") || lowerBundleId.contains("youtube") ||
                lowerBundleId.contains("tv") || lowerBundleId.contains("game") ||
                lowerBundleId.contains("steam") || lowerBundleId.contains("hulu") {
            return .entertainment
        }

        // Utilities: System apps, browsers, file managers, terminal
        else if lowerBundleId.contains("finder") || lowerBundleId.contains("terminal") ||
                lowerBundleId.contains("settings") || lowerBundleId.contains("preferences") ||
                lowerBundleId.contains("safari") || lowerBundleId.contains("chrome") ||
                lowerBundleId.contains("firefox") || lowerBundleId.contains("calendar") ||
                lowerBundleId.contains("mail") || lowerBundleId.contains("notes") {
            return .utilities
        }

        return .other
    }

    private func getCurrentDeviceID() -> String {
        // Get unique device identifier using IOKit
        if let uuid = getIOPlatformUUID() {
            return uuid
        }
        return Host.current().localizedName ?? "unknown"
    }

    private func getIOPlatformUUID() -> String? {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )

        defer { IOObjectRelease(platformExpert) }

        guard platformExpert != 0 else { return nil }

        return IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        ).takeRetainedValue() as? String
    }

    // MARK: - Copy Database for Backup

    func copyDatabaseToBackup(destinationURL: URL) throws {
        // Copy both databases and their WAL/SHM files
        let knowledgeURL = URL(fileURLWithPath: knowledgeDBPath)
        let screenTimeURL = URL(fileURLWithPath: screenTimeDBPath)

        let timestamp = ISO8601DateFormatter().string(from: Date())

        // Copy knowledge database
        if fileManager.fileExists(atPath: knowledgeDBPath) {
            let destKnowledge = destinationURL.appendingPathComponent("knowledgeC-\(timestamp).db")
            try fileManager.copyItem(at: knowledgeURL, to: destKnowledge)

            // Copy WAL and SHM files if they exist
            let walPath = knowledgeDBPath + "-wal"
            let shmPath = knowledgeDBPath + "-shm"

            if fileManager.fileExists(atPath: walPath) {
                try fileManager.copyItem(
                    at: URL(fileURLWithPath: walPath),
                    to: destKnowledge.appendingPathExtension("wal")
                )
            }

            if fileManager.fileExists(atPath: shmPath) {
                try fileManager.copyItem(
                    at: URL(fileURLWithPath: shmPath),
                    to: destKnowledge.appendingPathExtension("shm")
                )
            }
        }

        // Copy Screen Time database
        if fileManager.fileExists(atPath: screenTimeDBPath) {
            let destScreenTime = destinationURL.appendingPathComponent("RMAdminStore-\(timestamp).sqlite")
            try fileManager.copyItem(at: screenTimeURL, to: destScreenTime)

            let walPath = screenTimeDBPath + "-wal"
            let shmPath = screenTimeDBPath + "-shm"

            if fileManager.fileExists(atPath: walPath) {
                try fileManager.copyItem(
                    at: URL(fileURLWithPath: walPath),
                    to: destScreenTime.appendingPathExtension("wal")
                )
            }

            if fileManager.fileExists(atPath: shmPath) {
                try fileManager.copyItem(
                    at: URL(fileURLWithPath: shmPath),
                    to: destScreenTime.appendingPathExtension("shm")
                )
            }
        }
    }
}
