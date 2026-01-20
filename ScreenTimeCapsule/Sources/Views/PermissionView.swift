import SwiftUI
import AppKit

struct PermissionView: View {
    @EnvironmentObject var dataManager: ScreenTimeDataManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundColor(.accentColor)

            VStack(spacing: 12) {
                Text("Full Disk Access Required")
                    .font(.title)
                    .fontWeight(.bold)

                Text("ScreenTimeCapsule needs Full Disk Access to read Screen Time data from your Mac.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("How to grant access:")
                    .font(.headline)

                PermissionStep(
                    number: 1,
                    text: "Click the button below to open System Settings"
                )

                PermissionStep(
                    number: 2,
                    text: "Find ScreenTimeCapsule in the list"
                )

                PermissionStep(
                    number: 3,
                    text: "Toggle the switch to grant Full Disk Access"
                )

                PermissionStep(
                    number: 4,
                    text: "Return to ScreenTimeCapsule and click 'Check Again'"
                )
            }
            .padding(24)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .frame(maxWidth: 500)

            HStack(spacing: 16) {
                Button("Open System Settings") {
                    dataManager.requestFullDiskAccess()
                }
                .buttonStyle(.borderedProminent)

                Button("Check Again") {
                    dataManager.checkPermissions()
                    if dataManager.hasFullDiskAccess {
                        dataManager.refreshData()
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PermissionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor))

            Text(text)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

#Preview {
    PermissionView()
        .environmentObject(ScreenTimeDataManager.shared)
        .frame(width: 800, height: 600)
}
