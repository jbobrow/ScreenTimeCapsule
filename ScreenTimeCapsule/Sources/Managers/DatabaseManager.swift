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

    func fetchAppUsage(from startDate: Date, to endDate: Date) throws -> [AppUsage] {
        print("🔍 fetchAppUsage() called for range: \(startDate) to \(endDate)")

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

        let query = objects
            .filter(zStartDate >= startTimestamp && zStartDate <= endTimestamp)
            .filter(zStreamName == "/app/usage" || zStreamName == "/app/inFocus")

        var rowCount = 0
        var skippedCount = 0
        var eventsWithoutEndDate = 0

        for row in try db.prepare(query) {
            rowCount += 1

            // Log first few rows for debugging
            if rowCount <= 3 {
                print("🔍 Row \(rowCount): stream=\(row[zStreamName] ?? "nil"), bundleId=\(row[zValueString] ?? "nil"), hasEndDate=\(row[zEndDate] != nil)")
            }

            guard let bundleId = row[zValueString] else {
                skippedCount += 1
                continue
            }

            // Calculate duration
            let duration: Double
            if let end = row[zEndDate] {
                // Has end date - use actual duration
                duration = end - row[zStartDate]
            } else {
                // No end date - use default duration of 60 seconds per event
                // This means each app usage event counts as 1 minute
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

    func fetchHourlyAppUsageEvents(from startDate: Date, to endDate: Date) throws -> [(hour: Int, category: UsageCategory, usage: TimeInterval)] {
        print("🔍 fetchHourlyAppUsageEvents() called for range: \(startDate) to \(endDate)")

        let db = try Connection(knowledgeDBPath, readonly: true)

        let referenceDate = Date(timeIntervalSinceReferenceDate: 0)
        let startTimestamp = startDate.timeIntervalSince(referenceDate)
        let endTimestamp = endDate.timeIntervalSince(referenceDate)

        // Storage for hourly data by category
        var hourlyData: [Int: [UsageCategory: TimeInterval]] = [:]
        let calendar = Calendar.current

        // Use raw SQL to filter non-null dates
        let sql = """
            SELECT ZSTARTDATE, ZENDDATE, ZVALUESTRING
            FROM ZOBJECT
            WHERE (ZSTREAMNAME = '/app/usage' OR ZSTREAMNAME = '/app/inFocus')
            AND ZSTARTDATE IS NOT NULL
            AND ZSTARTDATE >= ?
            AND ZSTARTDATE <= ?
        """

        var eventCount = 0

        for row in try db.prepare(sql, startTimestamp, endTimestamp) {
            guard let bundleId = row[2] as? String else { continue }

            let eventStartTimestamp = row[0] as! Double

            // Calculate duration
            let duration: Double
            if let end = row[1] as? Double {
                duration = end - eventStartTimestamp
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
                for (category, usage) in categoryData {
                    result.append((hour: hour, category: category, usage: usage))
                }
            }
        }

        return result.sorted { $0.hour < $1.hour }
    }

    // MARK: - Fetch Daily App Usage Events

    func fetchDailyAppUsageEvents(from startDate: Date, to endDate: Date) throws -> [(day: String, category: UsageCategory, usage: TimeInterval)] {
        print("🔍 fetchDailyAppUsageEvents() called for range: \(startDate) to \(endDate)")

        let db = try Connection(knowledgeDBPath, readonly: true)

        let referenceDate = Date(timeIntervalSinceReferenceDate: 0)
        let startTimestamp = startDate.timeIntervalSince(referenceDate)
        let endTimestamp = endDate.timeIntervalSince(referenceDate)

        let calendar = Calendar.current
        let daysDiff = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = daysDiff <= 7 ? "E" : "MMM d" // "Mon" or "Jan 15"

        // Storage for daily data by category
        var dailyData: [String: [UsageCategory: TimeInterval]] = [:]

        // Use raw SQL to filter non-null dates
        let sql = """
            SELECT ZSTARTDATE, ZENDDATE, ZVALUESTRING
            FROM ZOBJECT
            WHERE (ZSTREAMNAME = '/app/usage' OR ZSTREAMNAME = '/app/inFocus')
            AND ZSTARTDATE IS NOT NULL
            AND ZSTARTDATE >= ?
            AND ZSTARTDATE <= ?
        """

        var eventCount = 0

        for row in try db.prepare(sql, startTimestamp, endTimestamp) {
            guard let bundleId = row[2] as? String else { continue }

            let eventStartTimestamp = row[0] as! Double

            // Calculate duration
            let duration: Double
            if let end = row[1] as? Double {
                duration = end - eventStartTimestamp
            } else {
                duration = 60.0 // Default 1 minute for events without end date
            }

            // Get the actual event timestamp
            let eventDate = Date(timeInterval: eventStartTimestamp, since: referenceDate)
            let dayStart = calendar.startOfDay(for: eventDate)
            let dayLabel = dateFormatter.string(from: dayStart)

            // Categorize the app
            let category = categorizeApp(bundleId: bundleId)

            // Add to daily data
            if dailyData[dayLabel] == nil {
                dailyData[dayLabel] = [:]
            }
            dailyData[dayLabel]![category, default: 0] += duration

            eventCount += 1
        }

        print("🔍 Processed \(eventCount) events for daily breakdown")

        // Convert to result format, maintaining chronological order
        var result: [(day: String, category: UsageCategory, usage: TimeInterval)] = []
        var currentDate = calendar.startOfDay(for: startDate)

        while currentDate < endDate {
            let dayLabel = dateFormatter.string(from: currentDate)
            if let categoryData = dailyData[dayLabel] {
                for (category, usage) in categoryData.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                    result.append((day: dayLabel, category: category, usage: usage))
                }
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return result
    }

    // MARK: - Fetch Devices

    func fetchDevices() throws -> [DeviceInfo] {
        guard fileManager.fileExists(atPath: screenTimeDBPath) else {
            // Return current device only if Screen Time DB doesn't exist
            return [DeviceInfo(
                id: getCurrentDeviceID(),
                name: Host.current().localizedName ?? "This Mac",
                model: "Mac"
            )]
        }

        let db = try Connection(screenTimeDBPath, readonly: true)

        // Try to fetch devices from the database
        do {
            let devices = Table("ZDEVICE")
            let zId = Expression<String>("ZIDENTIFIER")
            let zName = Expression<String?>("ZNAME")
            let zModel = Expression<String?>("ZMODEL")

            var deviceList: [DeviceInfo] = []

            for row in try db.prepare(devices) {
                deviceList.append(DeviceInfo(
                    id: row[zId],
                    name: row[zName] ?? "Unknown Device",
                    model: row[zModel] ?? "Unknown"
                ))
            }

            return deviceList.isEmpty ? [DeviceInfo(
                id: getCurrentDeviceID(),
                name: Host.current().localizedName ?? "This Mac",
                model: "Mac"
            )] : deviceList
        } catch {
            // If table doesn't exist, return current device
            return [DeviceInfo(
                id: getCurrentDeviceID(),
                name: Host.current().localizedName ?? "This Mac",
                model: "Mac"
            )]
        }
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
