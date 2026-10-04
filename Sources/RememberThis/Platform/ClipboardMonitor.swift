import AppKit
import Foundation

@MainActor
final class ClipboardMonitor {
    private let pasteboard: PasteboardWriting
    private let onTextCopied: (String, String?) -> Void
    private var timer: Timer?
    private var lastChangeCount: Int

    init(
        pasteboard: PasteboardWriting,
        onTextCopied: @escaping (String, String?) -> Void
    ) {
        self.pasteboard = pasteboard
        self.onTextCopied = onTextCopied
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForChange()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func acknowledgeOwnWrite() {
        lastChangeCount = pasteboard.changeCount
    }

    func checkForChange() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard let text = pasteboard.readPlainText() else { return }
        let sourceApplication = NSWorkspace.shared.frontmostApplication?.localizedName
        onTextCopied(text, sourceApplication)
    }
}
