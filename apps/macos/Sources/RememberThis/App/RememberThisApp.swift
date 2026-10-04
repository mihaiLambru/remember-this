import SwiftUI
import RememberThisCore

@main
struct RememberThisApp: App {
    @StateObject private var historyStore: ClipboardHistoryStore
    @StateObject private var coordinator: AppCoordinator

    init() {
        let historyStore = ClipboardHistoryStore(persister: FileClipboardHistoryPersister())
        _historyStore = StateObject(wrappedValue: historyStore)
        _coordinator = StateObject(wrappedValue: AppCoordinator(historyStore: historyStore))
    }

    var body: some Scene {
        WindowGroup("Remember This") {
            ClipboardLibraryView(
                historyStore: historyStore,
                shortcutError: coordinator.shortcutError,
                selectItem: coordinator.makeMainItem
            )
            .task {
                coordinator.start()
            }
        }
        .defaultSize(width: 620, height: 520)
        .commands {
            CommandGroup(after: .pasteboard) {
                Button("Show Clipboard History") { coordinator.showQuickPaste() }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
            }
        }
    }
}
