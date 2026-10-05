import SwiftUI

struct PairingQRCodeView: View {
    @ObservedObject var manager: PairingInvitationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Pair iPhone")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }
            }

            if let invitation = manager.invitation, let image = invitation.qrImage {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 270, height: 270)
                    .accessibilityLabel("Pairing QR code")

                Text("Scan this code in Remember This on your iPhone.")
                    .multilineTextAlignment(.center)

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let seconds = max(0, Int(invitation.expiresAt.timeIntervalSince(context.date)))
                    Text(seconds == 0 ? "Code expired" : "Expires in \(seconds / 60):\(String(format: "%02d", seconds % 60))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Generate New Code") { manager.createInvitation() }
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 76))
                    .foregroundStyle(.secondary)
                Text("This pairing code has expired.")
                Button("Generate Pairing Code") { manager.createInvitation() }
                    .buttonStyle(.borderedProminent)
            }

            Text("The code is valid for five minutes and can be used once.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(width: 390, height: 440)
        .onAppear {
            if manager.invitation == nil { manager.createInvitation() }
        }
        .onDisappear { manager.clearInvitation() }
    }
}
