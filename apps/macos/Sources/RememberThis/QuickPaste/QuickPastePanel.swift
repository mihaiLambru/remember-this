import AppKit
import SwiftUI
import RememberThisCore

@MainActor
final class QuickPastePanel: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var previouslyActiveApplication: NSRunningApplication?

    func show(
        items: [ClipboardItem],
        imageForAttachment: @escaping (ClipboardAttachment) -> NSImage?,
        onSelect: @escaping (ClipboardItem) -> Void
    ) {
        if panel?.isVisible == true {
            dismissAndRestoreFocus()
            return
        }
        previouslyActiveApplication = NSWorkspace.shared.frontmostApplication

        let selection = PickerSelection()
        let choose: (ClipboardItem) -> Void = { [weak self] item in
            onSelect(item)
            self?.dismissAndRestoreFocus()
        }
        let contentView = QuickPasteView(items: items, selection: selection, imageForAttachment: imageForAttachment, selectItem: choose)
        let hostingView = NSHostingView(rootView: contentView)
        let panel = makePanel(contentView: hostingView)
        self.panel = panel
        panel.onKey = { [weak self] code in
            switch code {
            case 53: self?.dismissAndRestoreFocus()
            case 125: selection.index = min(max(items.count - 1, 0), selection.index + 1)
            case 126: selection.index = max(0, selection.index - 1)
            case 36, 76:
                if items.indices.contains(selection.index) { choose(items[selection.index]) }
            default: return false
            }
            return true
        }

        position(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    private func makePanel(contentView: NSView) -> PickerPanel {
        let panel = PickerPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Clipboard History"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self
        panel.isMovableByWindowBackground = true
        panel.contentView = contentView
        return panel
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else {
            panel.center()
            return
        }
        let visibleFrame = screen.visibleFrame
        let originX = min(max(mouse.x - 230, visibleFrame.minX), visibleFrame.maxX - 460)
        let originY = min(max(mouse.y - 180, visibleFrame.minY), visibleFrame.maxY - 360)
        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    private func dismissAndRestoreFocus() {
        panel?.orderOut(nil)
        let application = previouslyActiveApplication
        previouslyActiveApplication = nil
        if let application, !application.isActive {
            application.activate()
        }
    }

    func windowWillClose(_ notification: Notification) {
        dismissAndRestoreFocus()
    }

    func windowDidResignKey(_ notification: Notification) {
        // A click elsewhere dismisses the picker without stealing focus back.
        panel?.orderOut(nil)
        previouslyActiveApplication = nil
    }
}

@MainActor
private final class PickerPanel: NSPanel {
    var onKey: ((UInt16) -> Bool)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, onKey?(event.keyCode) == true { return }
        super.sendEvent(event)
    }
}
