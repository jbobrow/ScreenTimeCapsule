import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var backupManager: BackupManager
    @State private var showingDirectoryPicker = false

    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(backupManager)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            BackupSettingsView()
                .environmentObject(backupManager)
                .tabItem {
                    Label("Backup", systemImage: "arrow.clockwise.circle")
                }

            DataSettingsView()
                .environmentObject(backupManager)
                .tabItem {
                    Label("Data", systemImage: "internaldrive")
                }
        }
        .frame(width: 600, height: 500)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var backupManager: BackupManager

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Text("General Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("About ScreenTimeCapsule")
                            .font(.headline)

                        Text("ScreenTimeCapsule backs up your Screen Time data and allows you to keep unlimited history.")
                            .font(.body)
                            .foregroundColor(.secondary)

                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Database Location")
                            .font(.headline)

                        Text("Screen Time data is read from:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("~/Library/Application Support/Knowledge/knowledgeC.db")
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(4)

                        Text("~/Library/Application Support/com.apple.screentime/")
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(4)
                    }
                }
                .padding()
            }
        }
        .formStyle(.grouped)
    }
}

struct BackupSettingsView: View {
    @EnvironmentObject var backupManager: BackupManager
    @State private var showingDirectoryPicker = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Backup Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.bottom, 8)

                    // Auto Backup Toggle
                    Toggle("Enable Automatic Backups", isOn: $backupManager.autoBackupEnabled)
                        .toggleStyle(.switch)

                    // Backup Interval
                    if backupManager.autoBackupEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Backup Interval")
                                .font(.headline)

                            Picker("Backup every:", selection: $backupManager.backupIntervalHours) {
                                Text("1 hour").tag(1)
                                Text("6 hours").tag(6)
                                Text("12 hours").tag(12)
                                Text("Daily").tag(24)
                                Text("Weekly").tag(168)
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    Divider()

                    // Backup Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Backup Location")
                            .font(.headline)

                        HStack {
                            Text(backupManager.backupDirectoryURL.path)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .padding(8)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(4)

                            Button("Change...") {
                                showingDirectoryPicker = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Divider()

                    // Manual Backup Button
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Manual Backup")
                            .font(.headline)

                        HStack {
                            Button("Backup Now") {
                                Task {
                                    try? await backupManager.performBackup()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(backupManager.isBackupInProgress)

                            if backupManager.isBackupInProgress {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Backing up...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let error = backupManager.lastError {
                            Text("Error: \(error)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding()
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $showingDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    backupManager.backupDirectoryURL = url
                }
            case .failure(let error):
                print("Directory picker error: \(error)")
            }
        }
    }
}

struct DataSettingsView: View {
    @EnvironmentObject var backupManager: BackupManager
    @State private var showingExportSheet = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Data Management")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.bottom, 8)

                    // Data Retention
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Data Retention")
                            .font(.headline)

                        Text("How long should backup data be kept?")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("Keep data for:", selection: $backupManager.dataRetentionDays) {
                            Text("Forever (Unlimited)").tag(0)
                            Text("3 months").tag(90)
                            Text("6 months").tag(180)
                            Text("1 year").tag(365)
                            Text("2 years").tag(730)
                            Text("5 years").tag(1825)
                        }
                        .pickerStyle(.menu)

                        if backupManager.dataRetentionDays > 0 {
                            Text("Backups older than \(backupManager.dataRetentionDays) days will be automatically deleted.")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.top, 4)
                        } else {
                            Text("All backup data will be kept indefinitely.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }

                    Divider()

                    // Backup Statistics
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Backup Statistics")
                            .font(.headline)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Backups")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(backupManager.backupStatus.totalBackups)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Size")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(backupManager.backupStatus.formattedDataSize)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)

                        if let oldest = backupManager.backupStatus.oldestDataDate {
                            Text("Oldest data: \(oldest, style: .date)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Export & Delete
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Export & Delete")
                            .font(.headline)

                        HStack(spacing: 12) {
                            Button("Export All Backups...") {
                                showingExportSheet = true
                            }
                            .buttonStyle(.bordered)

                            Button("Delete All Backups...") {
                                // TODO: Implement delete confirmation
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                    }
                }
                .padding()
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $showingExportSheet,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    do {
                        try backupManager.exportBackups(to: url)
                    } catch {
                        print("Export error: \(error)")
                    }
                }
            case .failure(let error):
                print("Export picker error: \(error)")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(BackupManager.shared)
}
