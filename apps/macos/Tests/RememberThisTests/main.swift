import Foundation
import RememberThisCore

private let runner = TestRunner()

runner.run("captures newest items first") {
    let store = runner.makeStore()
    store.capture(text: "first", sourceApplication: "Notes")
    store.capture(text: "second", sourceApplication: "Safari")
    runner.expect(store.items.map(\.text) == ["second", "first"])
    runner.expect(store.items.first?.sourceApplication == "Safari")
}

runner.run("deduplicates copied text") {
    let store = runner.makeStore()
    store.capture(text: "first", sourceApplication: nil)
    store.capture(text: "second", sourceApplication: nil)
    store.capture(text: "first", sourceApplication: "Notes")
    runner.expect(store.items.map(\.text) == ["first", "second"])
    runner.expect(store.items.count == 2)
    runner.expect(store.items.first?.sourceApplication == "Notes")
}

runner.run("promotes a selected item to the main position") {
    let store = runner.makeStore()
    store.capture(text: "first", sourceApplication: nil)
    store.capture(text: "second", sourceApplication: nil)
    store.promote(store.items[1])
    runner.expect(store.items.map(\.text) == ["first", "second"])
}

runner.run("trims history to its configured maximum") {
    let store = runner.makeStore()
    store.maximumItemCount = 10
    for index in 0..<12 {
        store.capture(text: "item \(index)", sourceApplication: nil)
    }
    runner.expect(store.items.count == 10)
    runner.expect(store.items.first?.text == "item 11")
    runner.expect(store.items.last?.text == "item 2")
}

runner.run("does not capture while disabled") {
    let store = runner.makeStore()
    store.isCaptureEnabled = false
    store.capture(text: "private", sourceApplication: nil)
    runner.expect(store.items.isEmpty)
}

runner.run("preserves exact whitespace and multiline text") {
    let store = runner.makeStore()
    let original = "\n  indented text\t\n\n"
    store.capture(text: original, sourceApplication: nil)
    runner.expect(store.items.first?.text == original)
}

runner.run("clamps invalid retention values without recursion") {
    let store = runner.makeStore()
    store.maximumItemCount = -20
    runner.expect(store.maximumItemCount == 10)
    store.maximumItemCount = 2_000
    runner.expect(store.maximumItemCount == 1_000)
}

runner.run("deletes and clears saved items") {
    let store = runner.makeStore()
    store.capture(text: "one", sourceApplication: nil)
    store.capture(text: "two", sourceApplication: nil)
    store.delete(store.items[1])
    runner.expect(store.items.map(\.text) == ["two"])
    store.clear()
    runner.expect(store.items.isEmpty)
}

runner.run("round trips exact text through disk persistence") {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Remember This Tests \(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let persister = FileClipboardHistoryPersister(fileURL: directory.appendingPathComponent("history.json"))
    do {
        runner.expect(try persister.load().isEmpty)
        let items = [ClipboardItem(text: "\nHello 👋\t\n")]
        try persister.save(items)
        runner.expect(try persister.load() == items)
        let store = ClipboardHistoryStore(persister: persister, preferences: UserDefaults(suiteName: "RememberThisTests.\(UUID().uuidString)")!)
        runner.expect(store.items == items)
        try persister.save([])
        runner.expect(try persister.load().isEmpty)
    } catch { runner.expect(false) }
}

runner.run("captures text and attachments as one history item") {
    let store = runner.makeStore()
    let attachment = ClipboardAttachment(
        filename: "plan.pdf",
        contentType: "application/pdf",
        byteCount: 128,
        storage: .localCopy(relativePath: "plan.pdf")
    )
    store.capture(text: "Please review", attachments: [attachment], sourceApplication: "Mail")
    runner.expect(store.items.count == 1)
    runner.expect(store.items[0].text == "Please review")
    runner.expect(store.items[0].attachments == [attachment])
}

runner.run("loads history saved before attachments were introduced") {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Clipboard Migration Tests \(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let historyURL = directory.appendingPathComponent("history.json")
    struct LegacyClipboardItem: Codable {
        let id: UUID
        let text: String
        let createdAt: Date
        let sourceApplication: String?
    }
    do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacyItem = LegacyClipboardItem(id: UUID(), text: "old entry", createdAt: .now, sourceApplication: "Notes")
        try JSONEncoder().encode([legacyItem]).write(to: historyURL)
        let loaded = try FileClipboardHistoryPersister(fileURL: historyURL).load()
        runner.expect(loaded.count == 1)
        runner.expect(loaded[0].text == "old entry")
        runner.expect(loaded[0].attachments.isEmpty)
    } catch {
        runner.expect(false)
    }
}

runner.run("stores image-only clipboard data locally and resolves it") {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Clipboard Attachment Tests \(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ClipboardAttachmentStore(directoryURL: directory)
    let imageData = Data([0x89, 0x50, 0x4E, 0x47])
    do {
        let attachment = try store.captureImageData(imageData, filename: "Pasted Image.png")
        runner.expect(attachment.isImage)
        runner.expect({
            guard let data = try? store.withResolvedURL(for: attachment, perform: { try Data(contentsOf: $0) }) else { return false }
            return data == imageData
        }())
    } catch {
        runner.expect(false)
    }
}

runner.run("references source files when a bookmark is available") {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Clipboard Reference Tests \(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let sourceURL = directory.appendingPathComponent("source.txt")
    let store = ClipboardAttachmentStore(directoryURL: directory.appendingPathComponent("cache"))
    do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("source".utf8).write(to: sourceURL)
        let attachment = try store.captureFile(at: sourceURL)
        runner.expect(attachment.byteCount == 6)
        runner.expect({
            guard let data = try? store.withResolvedURL(for: attachment, perform: { try Data(contentsOf: $0) }) else { return false }
            return data == Data("source".utf8)
        }())
    } catch {
        runner.expect(false)
    }
}

runner.run("copies a source file locally when a bookmark cannot be created") {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Clipboard Fallback Tests \(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let sourceURL = directory.appendingPathComponent("source.txt")
    let store = ClipboardAttachmentStore(
        directoryURL: directory.appendingPathComponent("cache"),
        bookmarkDataProvider: { _ in throw URLError(.cannotCreateFile) }
    )
    do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let expectedData = Data("fallback".utf8)
        try expectedData.write(to: sourceURL)
        let attachment = try store.captureFile(at: sourceURL)
        guard case .localCopy = attachment.storage else {
            runner.expect(false)
            return
        }
        runner.expect({
            guard let data = try? store.withResolvedURL(for: attachment, perform: { try Data(contentsOf: $0) }) else { return false }
            return data == expectedData
        }())
    } catch {
        runner.expect(false)
    }
}

runner.run("rejects attachments over the configured maximum size") {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Clipboard Size Tests \(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ClipboardAttachmentStore(directoryURL: directory)
    do {
        _ = try store.captureImageData(Data(repeating: 1, count: 5), filename: "large.png", maximumBytes: 4)
        runner.expect(false)
    } catch let error as ClipboardAttachmentError {
        runner.expect(error == .exceedsMaximumSize(filename: "large.png", maximumBytes: 4))
    } catch {
        runner.expect(false)
    }
}

if runner.failures == 0 {
    print("All \(runner.testCount) unit tests passed.")
} else {
    print("\(runner.failures) unit test assertion(s) failed.")
    exit(1)
}

private final class TestRunner: @unchecked Sendable {
    private(set) var failures = 0
    private(set) var testCount = 0

    func makeStore() -> ClipboardHistoryStore {
        let suiteName = "RememberThisTests.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suiteName)!
        return ClipboardHistoryStore(persister: InMemoryPersister(), preferences: preferences)
    }

    func run(_ name: String, test: () -> Void) {
        testCount += 1
        let before = failures
        test()
        print(failures == before ? "✓ \(name)" : "✗ \(name)")
    }

    func expect(
        _ condition: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard !condition else { return }
        failures += 1
        print("  Assertion failed at \(file):\(line)")
    }
}

private final class InMemoryPersister: ClipboardHistoryPersisting {
    private var items: [ClipboardItem] = []

    func load() throws -> [ClipboardItem] { items }

    func save(_ items: [ClipboardItem]) throws {
        self.items = items
    }
}
