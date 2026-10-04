import AppKit

protocol PasteboardWriting {
    func readPlainText() -> String?
    @discardableResult func write(text: String) -> Bool
    var changeCount: Int { get }
}

final class SystemPasteboardClient: PasteboardWriting {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int { pasteboard.changeCount }

    func readPlainText() -> String? {
        pasteboard.string(forType: .string)
    }

    @discardableResult func write(text: String) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}
