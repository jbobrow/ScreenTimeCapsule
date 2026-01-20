import XCTest
@testable import ScreenTimeCapsule

final class ScreenTimeCapsuleTests: XCTestCase {

    // MARK: - AppUsage Tests

    func testAppUsageFormattedTime() {
        // Given
        let appUsage = AppUsage(
            bundleIdentifier: "com.apple.Safari",
            appName: "Safari",
            totalTime: 3665, // 1 hour, 1 minute, 5 seconds
            startDate: Date(),
            endDate: Date()
        )

        // When
        let formatted = appUsage.formattedTime

        // Then
        XCTAssertEqual(formatted, "1h 1m")
    }

    func testAppUsageFormattedTimeMinutesOnly() {
        // Given
        let appUsage = AppUsage(
            bundleIdentifier: "com.apple.Safari",
            appName: "Safari",
            totalTime: 125, // 2 minutes, 5 seconds
            startDate: Date(),
            endDate: Date()
        )

        // When
        let formatted = appUsage.formattedTime

        // Then
        XCTAssertEqual(formatted, "2m")
    }

    // MARK: - UsageCategory Tests

    func testUsageCategoryColors() {
        // Test that all categories have colors assigned
        for category in UsageCategory.allCases {
            XCTAssertFalse(category.color.isEmpty)
        }
    }

    // MARK: - TimePeriod Tests

    func testTimePeriodToday() {
        // Given
        let period = TimePeriod.today
        let calendar = Calendar.current

        // When
        let range = period.dateRange

        // Then
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        // Allow 1 second tolerance for test execution time
        XCTAssertEqual(range.start.timeIntervalSince1970, startOfToday.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(range.end.timeIntervalSince1970, endOfToday.timeIntervalSince1970, accuracy: 1.0)
    }

    func testTimePeriodLast7Days() {
        // Given
        let period = TimePeriod.last7Days

        // When
        let range = period.dateRange

        // Then
        let daysDifference = Calendar.current.dateComponents([.day], from: range.start, to: range.end).day
        XCTAssertEqual(daysDifference, 7)
    }

    // MARK: - BackupStatus Tests

    func testBackupStatusFormattedDataSize() {
        // Given
        let status = BackupStatus(
            lastBackupDate: Date(),
            totalBackups: 5,
            totalDataSize: 1_500_000, // 1.5 MB
            oldestDataDate: Date(),
            newestDataDate: Date(),
            isBackupRunning: false
        )

        // When
        let formatted = status.formattedDataSize

        // Then
        XCTAssertTrue(formatted.contains("MB") || formatted.contains("KB"))
    }

    // MARK: - DeviceInfo Tests

    func testDeviceInfoInitialization() {
        // Given
        let deviceId = "test-device-id"
        let deviceName = "Test Mac"
        let model = "MacBook Pro"

        // When
        let device = DeviceInfo(id: deviceId, name: deviceName, model: model)

        // Then
        XCTAssertEqual(device.id, deviceId)
        XCTAssertEqual(device.name, deviceName)
        XCTAssertEqual(device.model, model)
    }

    // MARK: - UsageSummary Tests

    func testUsageSummaryFormattedTotalTime() {
        // Given
        let summary = UsageSummary(
            date: Date(),
            totalTime: 7200, // 2 hours
            categoryBreakdown: [:],
            topApps: [],
            deviceBreakdown: [:]
        )

        // When
        let formatted = summary.formattedTotalTime

        // Then
        XCTAssertEqual(formatted, "2h 0m")
    }

    func testUsageSummaryWithCategoryBreakdown() {
        // Given
        let categoryBreakdown: [UsageCategory: TimeInterval] = [
            .productivity: 3600,
            .entertainment: 1800,
            .social: 900
        ]

        let summary = UsageSummary(
            date: Date(),
            totalTime: 6300,
            categoryBreakdown: categoryBreakdown,
            topApps: [],
            deviceBreakdown: [:]
        )

        // Then
        XCTAssertEqual(summary.categoryBreakdown.count, 3)
        XCTAssertEqual(summary.categoryBreakdown[.productivity], 3600)
        XCTAssertEqual(summary.categoryBreakdown[.entertainment], 1800)
        XCTAssertEqual(summary.categoryBreakdown[.social], 900)
    }
}
