import AppKit
import Combine
import RememberThisCore

@MainActor
final class AppCoordinator: ObservableObject {
    private let historyStore: ClipboardHistoryStore
    private let pasteboard: SystemPasteboardClient
    private let picker: QuickPastePanel
    private let shortcut: GlobalShortcutManager
    private var monitor: ClipboardMonitor?
    private var hasStarted = false
    @Published private(set) var shortcutError: String?

    init(historyStore: ClipboardHistoryStore) {
        self.historyStore = historyStore
        let pasteboard = SystemPasteboardClient()
        self.pasteboard = pasteboard
        self.picker = QuickPastePanel()
        self.shortcut = GlobalShortcutManager()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        monitor = ClipboardMonitor(pasteboard: pasteboard) { [weak self] content, sourceApplication in
            self?.historyStore.capture(text: content.text, attachments: content.attachments, sourceApplication: sourceApplication)
            if let warning = content.warning {
                self?.shortcutError = warning
            }
        }
        monitor?.start()
        let status = shortcut.start { [weak self] in
            self?.showQuickPaste()
        }
        if status != 0 {
            shortcutError = "⌘⇧V could not be registered. Check whether another app uses this shortcut, then restart Remember This."
        }
    }

    func showQuickPaste() {
        monitor?.checkForChange()
        picker.show(items: historyStore.items, imageForAttachment: pasteboard.previewImage) { [weak self] item in
            self?.makeMainItem(item)
        }
    }

    func makeMainItem(_ item: ClipboardItem) {
        guard pasteboard.write(item: item) else { return }
        monitor?.acknowledgeOwnWrite()
        historyStore.promote(item)
    }

    func previewImage(for attachment: ClipboardAttachment) -> NSImage? {
        pasteboard.previewImage(for: attachment)
    }
}
