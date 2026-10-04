import SwiftUI
import AppKit
import RememberThisCore

final class PickerSelection: ObservableObject {
    @Published var index = 0
}

struct QuickPasteView: View {
    let items: [ClipboardItem]
    @ObservedObject var selection: PickerSelection
    let imageForAttachment: (ClipboardAttachment) -> NSImage?
    let selectItem: (ClipboardItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "doc.on.clipboard")
                Text("Clipboard History")
                    .font(.headline)
                Spacer()
                Text("Select an item, then paste with ⌘V")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            if items.isEmpty {
                ContentUnavailableView(
                    "No clipboard items yet",
                    systemImage: "clipboard",
                    description: Text("Copy some text, then press ⌘⇧V.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            Button {
                                selectItem(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.preview)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    AttachmentPreviewRow(attachments: item.attachments, imageForAttachment: imageForAttachment)
                                    if let sourceApplication = item.sourceApplication {
                                        Text(sourceApplication)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            .background(selection.index == index ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                            .id(index)
                        }
                    }
                    .padding()
                }
                .onChange(of: selection.index) { _, index in proxy.scrollTo(index) }
                }
            }
        }
        .frame(width: 460, height: 360)
    }
}

private struct AttachmentPreviewRow: View {
    let attachments: [ClipboardAttachment]
    let imageForAttachment: (ClipboardAttachment) -> NSImage?

    var body: some View {
        if !attachments.isEmpty {
            HStack(spacing: 6) {
                ForEach(attachments.prefix(4)) { attachment in
                    if attachment.isImage, let image = imageForAttachment(attachment) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    } else {
                        Label(attachment.filename, systemImage: "doc")
                            .font(.caption)
                            .lineLimit(1)
                            .frame(maxWidth: 130, alignment: .leading)
                    }
                }
                if attachments.count > 4 {
                    Text("+\(attachments.count - 4)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
