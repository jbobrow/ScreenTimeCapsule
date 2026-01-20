import Foundation
import Combine

class BackupManager: ObservableObject {
    static let shared = BackupManager()

    @Published var backupStatus: BackupStatus
    @Published var isBackupInProgress = false
    @Published var lastError: String?

    private let databaseManager = DatabaseManager.shared
    private let fileManager = FileManager.default
    private var backupTimer: Timer?

    // User preferences
    @Published var autoBackupEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoBackupEnabled, forKey: "autoBackupEnabled")
            if autoBackupEnabled {
                startAutoBackup()
            } else {
                stopAutoBackup()
            }
        }
    }

    @Published var backupIntervalHours: Int {
        didSet {
            UserDefaults.standard.set(backupIntervalHours, forKey: "backupIntervalHours")
            if autoBackupEnabled {
                startAutoBackup()
            }
        }
    }

    @Published var dataRetentionDays: Int {
        didSet {
            UserDefaults.standard.set(dataRetentionDays, forKey: "dataRetentionDays")
        }
    }

    @Published var backupDirectoryURL: URL {
        didSet {
            if let bookmarkData = try? backupDirectoryURL.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                UserDefaults.standard.set(bookmarkData, forKey: "backupDirectoryBookmark")
            }
        }
    }

    private init() {
        // Load preferences
        self.autoBackupEnabled = UserDefaults.standard.bool(forKey: "autoBackupEnabled")
        self.backupIntervalHours = UserDefaults.standard.integer(forKey: "backupIntervalHours")
        if self.backupIntervalHours == 0 {
            self.backupIntervalHours = 24 // Default: daily backups
        }

        self.dataRetentionDays = UserDefaults.standard.integer(forKey: "dataRetentionDays")
        if self.dataRetentionDays == 0 {
            self.dataRetentionDays = 0 // 0 = unlimited
        }

        // Load backup directory
        if let bookmarkData = UserDefaults.standard.data(forKey: "backupDirectoryBookmark"),
           let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: nil
           ) {
            self.backupDirectoryURL = url
        } else {
            // Default backup location
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.backupDirectoryURL = appSupport.appendingPathComponent("ScreenTimeCapsule/Backups")
        }

        // Initialize backup status
        self.backupStatus = BackupStatus(
            lastBackupDate: UserDefaults.standard.object(forKey: "lastBackupDate") as? Date,
            totalBackups: 0,
            totalDataSize: 0,
            oldestDataDate: nil,
            newestDataDate: nil,
            isBackupRunning: false
        )

        // Create backup directory if needed
        try? fileManager.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true)

        // Update backup status
        updateBackupStatus()

        // Start auto backup if enabled
        if autoBackupEnabled {
            startAutoBackup()
        }
    }

    // MARK: - Backup Operations

    func performBackup() async throws {
        await MainActor.run {
            isBackupInProgress = true
            lastError = nil
        }

        defer {
            Task { @MainActor in
                isBackupInProgress = false
            }
        }

        do {
            // Create timestamped backup directory
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let backupDir = backupDirectoryURL.appendingPathComponent(timestamp)
            try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)

            // Copy databases
            try databaseManager.copyDatabaseToBackup(destinationURL: backupDir)

            // Update last backup date
            UserDefaults.standard.set(Date(), forKey: "lastBackupDate")

            // Clean old backups if retention limit is set
            if dataRetentionDays > 0 {
                try cleanOldBackups()
            }

            // Update status
            await MainActor.run {
                updateBackupStatus()
            }

            print("Backup completed successfully to: \(backupDir.path)")
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
            }
            throw error
        }
    }

    private func cleanOldBackups() throws {
        guard dataRetentionDays > 0 else { return }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -dataRetentionDays, to: Date())!

        let contents = try fileManager.contentsOfDirectory(
            at: backupDirectoryURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )

        for url in contents {
            if let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate,
               creationDate < cutoffDate {
                try fileManager.removeItem(at: url)
                print("Deleted old backup: \(url.lastPathComponent)")
            }
        }
    }

    func updateBackupStatus() {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: backupDirectoryURL,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            )

            var totalSize: Int64 = 0
            var oldestDate: Date?
            var newestDate: Date?

            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])

                if let size = resourceValues.fileSize {
                    totalSize += Int64(size)
                }

                if let creationDate = resourceValues.creationDate {
                    if oldestDate == nil || creationDate < oldestDate! {
                        oldestDate = creationDate
                    }
                    if newestDate == nil || creationDate > newestDate! {
                        newestDate = creationDate
                    }
                }
            }

            backupStatus = BackupStatus(
                lastBackupDate: UserDefaults.standard.object(forKey: "lastBackupDate") as? Date,
                totalBackups: contents.count,
                totalDataSize: totalSize,
                oldestDataDate: oldestDate,
                newestDataDate: newestDate,
                isBackupRunning: isBackupInProgress
            )
        } catch {
            print("Error updating backup status: \(error)")
        }
    }

    // MARK: - Auto Backup

    private func startAutoBackup() {
        stopAutoBackup()

        let interval = TimeInterval(backupIntervalHours * 3600)
        backupTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                try? await self?.performBackup()
            }
        }

        print("Auto backup started with interval: \(backupIntervalHours) hours")
    }

    private func stopAutoBackup() {
        backupTimer?.invalidate()
        backupTimer = nil
        print("Auto backup stopped")
    }

    // MARK: - Export

    func exportBackups(to destinationURL: URL) throws {
        let contents = try fileManager.contentsOfDirectory(
            at: backupDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for url in contents {
            let destination = destinationURL.appendingPathComponent(url.lastPathComponent)
            try fileManager.copyItem(at: url, to: destination)
        }
    }
}
