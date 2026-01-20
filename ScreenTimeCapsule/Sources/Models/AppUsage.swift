import Foundation

// MARK: - App Usage Models

struct AppUsage: Identifiable, Codable {
    let id: UUID
    let bundleIdentifier: String
    let appName: String
    let totalTime: TimeInterval
    let startDate: Date
    let endDate: Date
    let deviceIdentifier: String?
    let category: UsageCategory

    init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        appName: String,
        totalTime: TimeInterval,
        startDate: Date,
        endDate: Date,
        deviceIdentifier: String? = nil,
        category: UsageCategory = .other
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.totalTime = totalTime
        self.startDate = startDate
        self.endDate = endDate
        self.deviceIdentifier = deviceIdentifier
        self.category = category
    }

    var formattedTime: String {
        let hours = Int(totalTime) / 3600
        let minutes = (Int(totalTime) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Usage Category

enum UsageCategory: String, Codable, CaseIterable {
    case productivity = "Productivity & Finance"
    case creativity = "Creativity"
    case entertainment = "Entertainment"
    case social = "Social Networking"
    case games = "Games"
    case reading = "Reading & Reference"
    case education = "Education"
    case health = "Health & Fitness"
    case other = "Other"

    var color: String {
        switch self {
        case .productivity: return "blue"
        case .creativity: return "teal"
        case .entertainment: return "purple"
        case .social: return "pink"
        case .games: return "orange"
        case .reading: return "green"
        case .education: return "indigo"
        case .health: return "red"
        case .other: return "gray"
        }
    }
}

// MARK: - Device Info

struct DeviceInfo: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let model: String
    let lastSeen: Date

    init(id: String, name: String, model: String = "Unknown", lastSeen: Date = Date()) {
        self.id = id
        self.name = name
        self.model = model
        self.lastSeen = lastSeen
    }
}

// MARK: - Usage Summary

struct UsageSummary: Codable {
    let date: Date
    let totalTime: TimeInterval
    let categoryBreakdown: [UsageCategory: TimeInterval]
    let topApps: [AppUsage]
    let deviceBreakdown: [String: TimeInterval]

    var formattedTotalTime: String {
        let hours = Int(totalTime) / 3600
        let minutes = (Int(totalTime) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Time Period

enum TimePeriod: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case last7Days = "Last 7 Days"
    case last30Days = "Last 30 Days"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case custom = "Custom"

    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        let endOfToday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)

        switch self {
        case .today:
            let startOfToday = calendar.startOfDay(for: now)
            return (startOfToday, endOfToday)
        case .yesterday:
            let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
            let endOfYesterday = calendar.startOfDay(for: now)
            return (startOfYesterday, endOfYesterday)
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return (start, now)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now)!
            return (start, now)
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)!.start
            return (startOfWeek, endOfToday)
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)!.start
            return (startOfMonth, endOfToday)
        case .custom:
            return (now, now)
        }
    }
}

// MARK: - Backup Status

struct BackupStatus: Codable {
    let lastBackupDate: Date?
    let totalBackups: Int
    let totalDataSize: Int64
    let oldestDataDate: Date?
    let newestDataDate: Date?
    let isBackupRunning: Bool

    var formattedDataSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalDataSize)
    }
}
