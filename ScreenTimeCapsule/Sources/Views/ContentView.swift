import SwiftUI
import Charts

struct ContentView: View {
    @EnvironmentObject var dataManager: ScreenTimeDataManager
    @EnvironmentObject var backupManager: BackupManager

    var body: some View {
        Group {
            if !dataManager.hasFullDiskAccess {
                PermissionView()
            } else {
                MainUsageView()
            }
        }
        .onAppear {
            dataManager.checkPermissions()
            if dataManager.hasFullDiskAccess {
                dataManager.refreshData()
            }
        }
    }
}

struct MainUsageView: View {
    @EnvironmentObject var dataManager: ScreenTimeDataManager
    @EnvironmentObject var backupManager: BackupManager
    @State private var selectedCategory: UsageCategory?

    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("App & Website Activity")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let summary = dataManager.usageSummary {
                        Text("Updated \(formattedDate(summary.date))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()

                Divider()

                // Device Selector
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Device")
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("", selection: $dataManager.selectedDevice) {
                            Text("All Devices").tag(nil as DeviceInfo?)
                            ForEach(dataManager.devices) { device in
                                Text(device.name).tag(device as DeviceInfo?)
                            }
                        }
                        .labelsHidden()
                    }
                }
                .padding()

                Divider()

                // Usage Summary with Navigation
                if let summary = dataManager.usageSummary {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Usage")
                                .foregroundColor(.secondary)
                            Spacer()

                            // Time Period Navigation
                            HStack(spacing: 4) {
                                Button(action: { dataManager.navigateToPrevious() }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .buttonStyle(.plain)
                                .help("Previous")

                                Menu {
                                    ForEach(TimePeriod.allCases.filter { $0 != .custom }, id: \.self) { period in
                                        Button(action: {
                                            dataManager.selectedTimePeriod = period
                                        }) {
                                            Text(period.rawValue)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(dataManager.currentPeriodLabel)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                }
                                .menuStyle(.borderlessButton)
                                .frame(minWidth: 140)

                                Button(action: { dataManager.navigateToNext() }) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .buttonStyle(.plain)
                                .help("Next")
                                .disabled(!dataManager.canNavigateForward)
                            }
                        }

                        Text(summary.formattedTotalTime)
                            .font(.system(size: 48, weight: .medium))

                        // Date range label
                        Text(dataManager.currentDateRangeLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                Divider()

                // Categories List
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // All Usage option
                        AllUsageRow(isSelected: selectedCategory == nil)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCategory = nil
                            }

                        ForEach(UsageCategory.allCases, id: \.self) { category in
                            CategoryRow(category: category, isSelected: selectedCategory == category)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedCategory = category
                                }
                        }
                    }
                }

                Spacer()

                // Backup Status
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.secondary)
                        Text("Last Backup")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if let lastBackup = backupManager.backupStatus.lastBackupDate {
                            Text(lastBackup, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Never")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
            .frame(minWidth: 280, maxWidth: 320)
        } detail: {
            // Detail View
            VStack(spacing: 0) {
                // Charts
                UsageChartView()
                    .frame(height: 300)
                    .padding()

                Divider()

                // App List
                AppListView(selectedCategory: selectedCategory)
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        Task {
                            try? await backupManager.performBackup()
                        }
                    }) {
                        Label("Backup Now", systemImage: "arrow.down.circle")
                    }
                    .disabled(backupManager.isBackupInProgress)
                }

                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        dataManager.refreshData()
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(dataManager.isLoading)
                }
            }
        }
        .alert("Error", isPresented: .constant(dataManager.errorMessage != nil)) {
            Button("OK") {
                dataManager.errorMessage = nil
            }
        } message: {
            if let error = dataManager.errorMessage {
                Text(error)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct AllUsageRow: View {
    let isSelected: Bool
    @EnvironmentObject var dataManager: ScreenTimeDataManager

    var body: some View {
        HStack {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 12, height: 12)

            Text("All usage")
                .font(.subheadline)

            Spacer()

            if let summary = dataManager.usageSummary {
                Text(dataManager.formatDuration(summary.totalTime))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}

struct CategoryRow: View {
    let category: UsageCategory
    let isSelected: Bool
    @EnvironmentObject var dataManager: ScreenTimeDataManager

    var body: some View {
        HStack {
            Circle()
                .fill(categoryColor)
                .frame(width: 12, height: 12)

            Text(category.rawValue)
                .font(.subheadline)

            Spacer()

            Text(dataManager.formatDuration(dataManager.getTotalTimeForCategory(category)))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }

    private var categoryColor: Color {
        switch category.color {
        case "blue": return .blue
        case "teal": return .teal
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        case "green": return .green
        case "indigo": return .indigo
        case "red": return .red
        case "brown": return .brown
        default: return .gray
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ScreenTimeDataManager.shared)
        .environmentObject(BackupManager.shared)
        .frame(width: 1000, height: 700)
}
