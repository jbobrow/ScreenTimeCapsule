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

    private let databaseManager = DatabaseManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        checkPermissions()
        loadDevices()

        // Auto-refresh when time period changes
        $selectedTimePeriod
            .sink { [weak self] _ in
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
                    if selectedDevice == nil, let first = fetchedDevices.first {
                        selectedDevice = first
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

        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }

            do {
                let dateRange: (start: Date, end: Date)
                if selectedTimePeriod == .custom, let customRange = customDateRange {
                    dateRange = customRange
                } else {
                    dateRange = selectedTimePeriod.dateRange
                }

                let usage = try databaseManager.fetchAppUsage(
                    from: dateRange.start,
                    to: dateRange.end
                )

                let summary = calculateSummary(from: usage, dateRange: dateRange)

                await MainActor.run {
                    self.currentUsage = usage
                    self.usageSummary = summary
                    self.isLoading = false
                }
            } catch {
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

    func getWeeklyUsageData() -> [(day: String, usage: TimeInterval)] {
        guard selectedTimePeriod == .last7Days || selectedTimePeriod == .thisWeek else {
            return []
        }

        var dailyData: [String: TimeInterval] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E" // Day of week (Mon, Tue, etc.)

        for app in currentUsage {
            let dayKey = dateFormatter.string(from: app.startDate)
            dailyData[dayKey, default: 0] += app.totalTime
        }

        let daysOfWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return daysOfWeek.map { day in
            (day: day, usage: dailyData[day] ?? 0)
        }
    }
}
