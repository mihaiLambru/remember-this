import Combine
import Foundation

public final class ClipboardHistoryStore: ObservableObject {
    @Published public private(set) var items: [ClipboardItem]
    @Published public private(set) var storageError: String?
    @Published public var isCaptureEnabled: Bool {
        didSet { preferences.set(isCaptureEnabled, forKey: Keys.captureEnabled) }
    }
    @Published public var maximumItemCount: Int {
        didSet {
            let boundedCount = max(10, min(maximumItemCount, 1_000))
            if maximumItemCount != boundedCount {
                maximumItemCount = boundedCount
                return
            }
            preferences.set(maximumItemCount, forKey: Keys.maximumItemCount)
            trimAndPersist()
        }
    }

    private let persister: ClipboardHistoryPersisting
    private let preferences: UserDefaults

    public init(persister: ClipboardHistoryPersisting, preferences: UserDefaults = .standard) {
        self.persister = persister
        self.preferences = preferences
        do {
            self.items = try persister.load()
        } catch {
            self.items = []
            self.storageError = "Saved history could not be read. New items will be kept only for this session until you clear history."
            self.canPersist = false
        }
        self.isCaptureEnabled = preferences.object(forKey: Keys.captureEnabled) as? Bool ?? true
        self.maximumItemCount = max(10, min(preferences.object(forKey: Keys.maximumItemCount) as? Int ?? 100, 1_000))
        self.items = Array(items.prefix(maximumItemCount))
    }

    public func capture(text: String, sourceApplication: String?) {
        guard isCaptureEnabled else { return }
        guard !text.isEmpty else { return }

        items.removeAll { $0.text == text }
        items.insert(ClipboardItem(text: text, sourceApplication: sourceApplication), at: 0)
        trimAndPersist()
    }

    public func promote(_ item: ClipboardItem) {
        guard let index = items.firstIndex(of: item) else { return }
        let selectedItem = items.remove(at: index)
        items.insert(selectedItem, at: 0)
        persist()
    }

    public func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    public func clear() {
        canPersist = true
        items.removeAll()
        persist()
    }

    private func trimAndPersist() {
        if items.count > maximumItemCount {
            items = Array(items.prefix(maximumItemCount))
        }
        persist()
    }

    private func persist() {
        guard canPersist else { return }
        do {
            try persister.save(items)
            storageError = nil
        } catch {
            storageError = "History could not be saved. Items are still available for this session."
        }
    }

    private var canPersist = true

    private enum Keys {
        static let captureEnabled = "captureEnabled"
        static let maximumItemCount = "maximumItemCount"
    }
}
