import AppKit
import RememberThisCore

struct PasteboardContent {
    let text: String
    let attachments: [ClipboardAttachment]
    let warning: String?
}

protocol PasteboardWriting {
    func readContent() -> PasteboardContent?
    @discardableResult func write(item: ClipboardItem) -> Bool
    var changeCount: Int { get }
}

final class SystemPasteboardClient: PasteboardWriting {
    private let pasteboard: NSPasteboard
    private let attachmentStore: ClipboardAttachmentStore

    init(pasteboard: NSPasteboard = .general, attachmentStore: ClipboardAttachmentStore = ClipboardAttachmentStore()) {
        self.pasteboard = pasteboard
        self.attachmentStore = attachmentStore
    }

    var changeCount: Int { pasteboard.changeCount }

    func readContent() -> PasteboardContent? {
        let text = pasteboard.string(forType: .string) ?? ""
        var attachments: [ClipboardAttachment] = []
        var warning: String?

        for item in pasteboard.pasteboardItems ?? [] {
            if let fileURLString = item.string(forType: .fileURL), let fileURL = URL(string: fileURLString) {
                do {
                    attachments.append(try attachmentStore.captureFile(at: fileURL))
                } catch let error as ClipboardAttachmentError {
                    warning = error.localizedDescription
                } catch {
                    warning = "\(fileURL.lastPathComponent) could not be attached."
                }
                continue
            }

            if let data = item.data(forType: .png) {
                captureImage(data, filename: "Pasted Image.png", contentType: "image/png", attachments: &attachments, warning: &warning)
            } else if let data = item.data(forType: .tiff) {
                captureImage(data, filename: "Pasted Image.tiff", contentType: "image/tiff", attachments: &attachments, warning: &warning)
            }
        }

        guard !text.isEmpty || !attachments.isEmpty else { return nil }
        return PasteboardContent(text: text, attachments: attachments, warning: warning)
    }

    @discardableResult func write(item: ClipboardItem) -> Bool {
        pasteboard.clearContents()
        var pasteboardItems: [NSPasteboardItem] = []

        if !item.text.isEmpty {
            let textItem = NSPasteboardItem()
            textItem.setString(item.text, forType: .string)
            pasteboardItems.append(textItem)
        }

        for attachment in item.attachments {
            guard let pasteboardItem = attachmentStore.withResolvedURL(for: attachment, perform: { url -> NSPasteboardItem in
                let pasteboardItem = NSPasteboardItem()
                pasteboardItem.setString(url.absoluteString, forType: .fileURL)
                if let imageType = imagePasteboardType(for: attachment), let imageData = try? Data(contentsOf: url) {
                    pasteboardItem.setData(imageData, forType: imageType)
                }
                return pasteboardItem
            }) else { continue }
            pasteboardItems.append(pasteboardItem)
        }

        guard !pasteboardItems.isEmpty else { return false }
        return pasteboard.writeObjects(pasteboardItems)
    }

    func previewImage(for attachment: ClipboardAttachment) -> NSImage? {
        attachmentStore.withResolvedURL(for: attachment) { NSImage(contentsOf: $0) } ?? nil
    }

    private func captureImage(
        _ data: Data,
        filename: String,
        contentType: String,
        attachments: inout [ClipboardAttachment],
        warning: inout String?
    ) {
        do {
            attachments.append(try attachmentStore.captureImageData(data, filename: filename, contentType: contentType))
        } catch let error as ClipboardAttachmentError {
            warning = error.localizedDescription
        } catch {
            warning = "The pasted image could not be attached."
        }
    }

    private func imagePasteboardType(for attachment: ClipboardAttachment) -> NSPasteboard.PasteboardType? {
        switch attachment.contentType {
        case "image/png": .png
        case "image/tiff": .tiff
        default: nil
        }
    }
}
