import SwiftUI
import RememberThisCore

struct SettingsView: View {
    @ObservedObject var historyStore: ClipboardHistoryStore
    @ObservedObject var pairingInvitationManager: PairingInvitationManager
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingPairingQRCode = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Settings")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }
            }

            Toggle("Save copied plain text", isOn: $historyStore.isCaptureEnabled)

            Stepper(
                "Keep up to \(historyStore.maximumItemCount) items",
                value: $historyStore.maximumItemCount,
                in: 10...1_000,
                step: 10
            )

            VStack(alignment: .leading, spacing: 5) {
                Text("Quick Paste")
                    .font(.headline)
                Text("Press ⌘⇧V anywhere to choose a saved item. Selecting it makes it your current clipboard, ready for ⌘V.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Pairing")
                    .font(.headline)
                Text("Pair an iPhone on your local network to share content with this Mac.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Pair iPhone…") {
                    isShowingPairingQRCode = true
                }
            }

            Divider()

            Button("Clear Clipboard History", role: .destructive) {
                historyStore.clear()
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 420, height: 430)
        .sheet(isPresented: $isShowingPairingQRCode) {
            PairingQRCodeView(manager: pairingInvitationManager)
        }
    }
}
