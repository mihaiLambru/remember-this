import SwiftUI
import AppKit
import RememberThisCore

struct ClipboardLibraryView: View {
    @ObservedObject var historyStore: ClipboardHistoryStore
    let shortcutError: String?
    let selectItem: (ClipboardItem) -> Void
    let imageForAttachment: (ClipboardAttachment) -> NSImage?
    let pairingInvitationManager: PairingInvitationManager
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if historyStore.items.isEmpty {
                    ContentUnavailableView(
                        "Your clipboard history is empty",
                        systemImage: "clipboard",
                        description: Text("Copy plain text anywhere on your Mac and it will appear here.")
                    )
                } else {
                    List {
                        ForEach(historyStore.items) { item in
                            ClipboardRow(item: item, imageForAttachment: imageForAttachment)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectItem(item)
                                }
                                .contextMenu {
                                    Button("Make Current Clipboard") {
                                        selectItem(item)
                                    }
                                    Button("Delete", role: .destructive) {
                                        historyStore.delete(item)
                                    }
                                }
                        }
                        .onDelete { offsets in
                            offsets.map { historyStore.items[$0] }.forEach(historyStore.delete)
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle("Clipboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(historyStore: historyStore, pairingInvitationManager: pairingInvitationManager)
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
            if let shortcutError {
                Text(shortcutError).font(.caption).padding()
            }
            if let storageError = historyStore.storageError {
                Text(storageError).font(.caption).padding()
            }
            }
        }
        .frame(minWidth: 460, minHeight: 340)
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    let imageForAttachment: (ClipboardAttachment) -> NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.preview)
                .font(.body)
                .lineLimit(3)
            AttachmentPreviewRow(attachments: item.attachments, imageForAttachment: imageForAttachment)
            HStack(spacing: 6) {
                if let sourceApplication = item.sourceApplication {
                    Text(sourceApplication)
                }
                Text(item.createdAt, style: .relative)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct AttachmentPreviewRow: View {
    let attachments: [ClipboardAttachment]
    let imageForAttachment: (ClipboardAttachment) -> NSImage?

    var body: some View {
        if !attachments.isEmpty {
            HStack(spacing: 8) {
                ForEach(attachments.prefix(5)) { attachment in
                    if attachment.isImage, let image = imageForAttachment(attachment) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Label(attachment.filename, systemImage: "doc.fill")
                            .font(.caption)
                            .lineLimit(1)
                            .frame(maxWidth: 150, alignment: .leading)
                    }
                }
                if attachments.count > 5 {
                    Text("+\(attachments.count - 5)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
