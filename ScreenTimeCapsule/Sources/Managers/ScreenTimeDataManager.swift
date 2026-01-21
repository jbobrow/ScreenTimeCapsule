import Foundation
import AppKit
import Combine

class ScreenTimeDataManager: ObservableObject {
    static let shared = ScreenTimeDataManager()

    @Published var currentUsage: [AppUsage] = []
    @Published var usageSummary: UsageSummary?
    @Published var devices: [DeviceInfo] = []
    @Published var selectedDevice: DeviceInfo?
    @Published var selectedTimePeriod: TimePeriod = .today
    @Published var customDateRange: (start: Date, end: Date)?
    @Published var isLoading = false
    @Published var hasFullDiskAccess = false
    @Published var errorMessage: String?

    // Navigation
    @Published var navigationOffset: Int = 0
    var canNavigateForward: Bool {
        navigationOffset < 0
    }
    var currentDateRangeLabel: String {
        let dateRange = getCurrentDateRange()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        if selectedTimePeriod == .today || selectedTimePeriod == .yesterday {
            return formatter.string(from: dateRange.start)
        } else {
            return "\(formatter.string(from: dateRange.start)) - \(formatter.string(from: dateRange.end))"
        }
    }

    private let databaseManager = DatabaseManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        checkPermissions()
        loadDevices()

        // Auto-refresh when time period changes
        $selectedTimePeriod
            .sink { [weak self] _ in
                self?.navigationOffset = 0  // Reset navigation when period changes
                self?.refreshData()
            }
            .store(in: &cancellables)

        $selectedDevice
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Permissions

    func checkPermissions() {
        hasFullDiskAccess = databaseManager.checkDatabaseAccess()
    }

    func requestFullDiskAccess() {
        // Open System Preferences to Privacy & Security
        let prefPaneURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(prefPaneURL)
    }

    // MARK: - Data Loading

    func loadDevices() {
        Task {
            do {
                let fetchedDevices = try databaseManager.fetchDevices()
                await MainActor.run {
                    self.devices = fetchedDevices
                    // If no devices available (Knowledge DB only), don't set selectedDevice
                    // This will cause queries to run without device filtering
                    if !fetchedDevices.isEmpty {
                        if selectedDevice == nil, let first = fetchedDevices.first {
                            selectedDevice = first
                        }
                    } else {
                        selectedDevice = nil
                        print("ℹ️ Device filtering unavailable - will show aggregated data from all devices")
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load devices: \(error.localizedDescription)"
                }
            }
        }
    }

    func refreshData() {
        guard hasFullDiskAccess else {
            errorMessage = "Full Disk Access required. Please grant permission in System Settings."
            return
        }

        print("🔄 refreshData() called")

        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }

            do {
                let dateRange = getCurrentDateRange()

                print("📅 Fetching data from \(dateRange.start) to \(dateRange.end)")
                print("📅 Selected period: \(selectedTimePeriod.rawValue)")

                let usage = try databaseManager.fetchAppUsage(
                    from: dateRange.start,
                    to: dateRange.end,
                    deviceId: selectedDevice?.id
                )

                print("📊 Fetched \(usage.count) app usage records")
                if usage.isEmpty {
                    print("⚠️ No usage data found for the selected time period")
                } else {
                    print("✅ Top apps: \(usage.prefix(3).map { "\($0.appName): \($0.formattedTime)" }.joined(separator: ", "))")
                }

                let summary = calculateSummary(from: usage, dateRange: dateRange)

                await MainActor.run {
                    self.currentUsage = usage
                    self.usageSummary = summary
                    self.isLoading = false
                    print("✅ Data loaded and UI updated")
                }
            } catch {
                print("❌ Error fetching data: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to load data: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func calculateSummary(from usage: [AppUsage], dateRange: (start: Date, end: Date)) -> UsageSummary {
        let totalTime = usage.reduce(0) { $0 + $1.totalTime }

        var categoryBreakdown: [UsageCategory: TimeInterval] = [:]
        for app in usage {
            categoryBreakdown[app.category, default: 0] += app.totalTime
        }

        var deviceBreakdown: [String: TimeInterval] = [:]
        for app in usage {
            let deviceId = app.deviceIdentifier ?? "Unknown"
            deviceBreakdown[deviceId, default: 0] += app.totalTime
        }

        let topApps = Array(usage.prefix(10))

        return UsageSummary(
            date: dateRange.start,
            totalTime: totalTime,
            categoryBreakdown: categoryBreakdown,
            topApps: topApps,
            deviceBreakdown: deviceBreakdown
        )
    }

    // MARK: - Helper Methods

    func getUsageForCategory(_ category: UsageCategory) -> [AppUsage] {
        return currentUsage.filter { $0.category == category }
    }

    func getTotalTimeForCategory(_ category: UsageCategory) -> TimeInterval {
        return getUsageForCategory(category).reduce(0) { $0 + $1.totalTime }
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - Chart Data

    func getHourlyUsageData() -> [(hour: Int, usage: TimeInterval)] {
        var hourlyData: [Int: TimeInterval] = [:]

        for app in currentUsage {
            let hour = Calendar.current.component(.hour, from: app.startDate)
            hourlyData[hour, default: 0] += app.totalTime
        }

        return hourlyData.map { (hour: $0.key, usage: $0.value) }
            .sorted { $0.hour < $1.hour }
    }

    func getHourlyUsageDataByCategory() -> [(hour: Int, category: UsageCategory, usage: TimeInterval)] {
        // Fetch hourly events directly from database with actual timestamps
        let dateRange = getCurrentDateRange()

        do {
            let hourlyEvents = try DatabaseManager.shared.fetchHourlyAppUsageEvents(
                from: dateRange.start,
                to: dateRange.end,
                deviceId: selectedDevice?.id
            )
            // Already sorted by hour and category sortOrder in DatabaseManager
            return hourlyEvents
        } catch {
            print("❌ Error fetching hourly usage data: \(error)")
            return []
        }
    }

    func getDailyUsageDataByCategory() -> [(day: String, category: UsageCategory, usage: TimeInterval)] {
        let dateRange = getCurrentDateRange()
        let calendar = Calendar.current
        let daysDiff = calendar.dateComponents([.day], from: dateRange.start, to: dateRange.end).day ?? 0

        // If period is <= 1 day, return empty (use hourly instead)
        guard daysDiff > 1 else { return [] }

        do {
            let dailyEvents = try DatabaseManager.shared.fetchDailyAppUsageEvents(
                from: dateRange.start,
                to: dateRange.end,
                deviceId: selectedDevice?.id
            )
            // Already sorted by day and category sortOrder in DatabaseManager
            return dailyEvents
        } catch {
            print("❌ Error fetching daily usage data: \(error)")
            return []
        }
    }

    func getWeeklyUsageData() -> [(day: String, usage: TimeInterval)] {
        // Works for any multi-day period
        let dateRange = getCurrentDateRange()
        let calendar = Calendar.current
        let daysDiff = calendar.dateComponents([.day], from: dateRange.start, to: dateRange.end).day ?? 0

        // If period is <= 1 day, return empty (use hourly instead)
        guard daysDiff > 1 else { return [] }

        var dailyData: [Date: TimeInterval] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = daysDiff <= 7 ? "E" : "MMM d" // "Mon" or "Jan 15"

        // Build usage by aggregating events from fetchAppUsage results
        // Note: currentUsage has events aggregated already, but we need daily breakdown
        // This is a limitation - we'll need to re-fetch with daily granularity in future
        // For now, distribute evenly across the range

        // Simple daily distribution for now
        var currentDate = calendar.startOfDay(for: dateRange.start)
        var days: [(day: String, usage: TimeInterval)] = []

        while currentDate < dateRange.end {
            let dayLabel = dateFormatter.string(from: currentDate)
            // In a real implementation, we'd query the database for each day
            // For now, this will show 0 unless we improve the data fetching
            days.append((day: dayLabel, usage: 0))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return days
    }

    // MARK: - Navigation

    func navigateToPrevious() {
        navigationOffset -= 1
        refreshData()
    }

    func navigateToNext() {
        guard canNavigateForward else { return }
        navigationOffset += 1
        refreshData()
    }

    func getCurrentDateRange() -> (start: Date, end: Date) {
        if selectedTimePeriod == .custom, let customRange = customDateRange {
            return customRange
        }

        let calendar = Calendar.current
        let now = Date()

        let baseRange = selectedTimePeriod.dateRange

        // Apply navigation offset
        switch selectedTimePeriod {
        case .today, .yesterday:
            let offsetDays = navigationOffset + (selectedTimePeriod == .yesterday ? -1 : 0)
            let targetDate = calendar.date(byAdding: .day, value: offsetDays, to: now)!
            let start = calendar.startOfDay(for: targetDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)

        case .last7Days:
            let start = calendar.date(byAdding: .day, value: navigationOffset * 7 - 7, to: now)!
            let end = calendar.date(byAdding: .day, value: navigationOffset * 7, to: now)!
            return (start, end)

        case .last30Days:
            let start = calendar.date(byAdding: .day, value: navigationOffset * 30 - 30, to: now)!
            let end = calendar.date(byAdding: .day, value: navigationOffset * 30, to: now)!
            return (start, end)

        case .thisWeek:
            let weekOffset = navigationOffset
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)!.start
            let targetStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startOfWeek)!
            let targetEnd = calendar.date(byAdding: .day, value: 7, to: targetStart)!
            return (targetStart, targetEnd)

        case .thisMonth:
            let monthOffset = navigationOffset
            let startOfMonth = calendar.dateInterval(of: .month, for: now)!.start
            let targetStart = calendar.date(byAdding: .month, value: monthOffset, to: startOfMonth)!
            let targetEnd = calendar.date(byAdding: .month, value: 1, to: targetStart)!
            return (targetStart, targetEnd)

        case .custom:
            return baseRange
        }
    }
}
