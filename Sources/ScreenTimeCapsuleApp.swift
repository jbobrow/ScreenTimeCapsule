import SwiftUI
import AppKit

@main
struct ScreenTimeCapsuleApp: App {
    @StateObject private var dataManager = ScreenTimeDataManager.shared
    @StateObject private var backupManager = BackupManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .environmentObject(backupManager)
                .frame(minWidth: 900, minHeight: 700)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About ScreenTimeCapsule") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.applicationName: "ScreenTimeCapsule",
                            NSApplication.AboutPanelOptionKey.applicationVersion: "1.0.0",
                            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "© 2026 ScreenTimeCapsule"
                        ]
                    )
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(backupManager)
        }
    }
}
