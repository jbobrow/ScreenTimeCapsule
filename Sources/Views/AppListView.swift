import SwiftUI
import AppKit

struct AppListView: View {
    let selectedCategory: UsageCategory?
    @EnvironmentObject var dataManager: ScreenTimeDataManager
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding()

            // Column headers
            HStack {
                Text("Apps")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 100, alignment: .trailing)
                Text("Limits")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 100, alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // App list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredApps) { app in
                        AppRow(app: app)
                        Divider()
                    }
                }
            }
        }
    }

    private var filteredApps: [AppUsage] {
        var apps = dataManager.currentUsage

        // Filter by category if selected
        if let category = selectedCategory {
            apps = apps.filter { $0.category == category }
        }

        // Filter by search text
        if !searchText.isEmpty {
            apps = apps.filter {
                $0.appName.localizedCaseInsensitiveContains(searchText) ||
                $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            }
        }

        return apps
    }
}

struct AppRow: View {
    let app: AppUsage

    var body: some View {
        HStack(spacing: 12) {
            // App icon
            if let icon = getAppIcon(for: app.bundleIdentifier) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(categoryColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(app.appName.prefix(1)))
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    )
            }

            // App name
            VStack(alignment: .leading, spacing: 2) {
                Text(app.appName)
                    .font(.body)
                if let deviceId = app.deviceIdentifier {
                    Text(deviceId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Usage time
            Text(app.formattedTime)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)

            // Limits (placeholder)
            Text("—")
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var categoryColor: Color {
        switch app.category.color {
        case "blue": return .blue
        case "teal": return .teal
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        case "green": return .green
        case "indigo": return .indigo
        case "red": return .red
        default: return .gray
        }
    }

    private func getAppIcon(for bundleIdentifier: String) -> NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
}

#Preview {
    AppListView(selectedCategory: nil)
        .environmentObject(ScreenTimeDataManager.shared)
        .frame(width: 600, height: 400)
}
