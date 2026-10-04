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
