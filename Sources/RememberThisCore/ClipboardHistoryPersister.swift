import Foundation

public protocol ClipboardHistoryPersisting {
    func load() throws -> [ClipboardItem]
    func save(_ items: [ClipboardItem]) throws
}

public final class FileClipboardHistoryPersister: ClipboardHistoryPersisting {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public init(fileManager: FileManager = .default) {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let directory = applicationSupport.appending(path: "RememberThis", directoryHint: .isDirectory)
        fileURL = directory.appending(path: "clipboard-history.json")
    }

    public func load() throws -> [ClipboardItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([ClipboardItem].self, from: Data(contentsOf: fileURL))
    }

    public func save(_ items: [ClipboardItem]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(items)
        try data.write(to: fileURL, options: .atomic)
    }
}
