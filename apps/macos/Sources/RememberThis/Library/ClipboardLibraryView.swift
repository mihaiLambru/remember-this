import SwiftUI
import RememberThisCore

struct ClipboardLibraryView: View {
    @ObservedObject var historyStore: ClipboardHistoryStore
    let shortcutError: String?
    let selectItem: (ClipboardItem) -> Void
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
                            ClipboardRow(item: item)
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
            SettingsView(historyStore: historyStore)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.preview)
                .font(.body)
                .lineLimit(3)
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
