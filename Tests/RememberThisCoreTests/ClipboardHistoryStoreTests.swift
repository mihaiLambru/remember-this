import Foundation
import XCTest
@testable import RememberThisCore

final class ClipboardHistoryStoreTests: XCTestCase {
    func testCaptureAddsNewestItemFirst() {
        let store = makeStore()
        store.capture(text: "first", sourceApplication: "Notes")
        store.capture(text: "second", sourceApplication: "Safari")

        XCTAssertEqual(store.items.map(\.text), ["second", "first"])
        XCTAssertEqual(store.items.first?.sourceApplication, "Safari")
    }

    func testCaptureDeduplicatesTextAndUpdatesItsSource() {
        let store = makeStore()
        store.capture(text: "first", sourceApplication: nil)
        store.capture(text: "second", sourceApplication: nil)
        store.capture(text: "first", sourceApplication: "Notes")

        XCTAssertEqual(store.items.map(\.text), ["first", "second"])
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items.first?.sourceApplication, "Notes")
    }

    func testPromoteMovesSelectedItemToMainPosition() {
        let store = makeStore()
        store.capture(text: "first", sourceApplication: nil)
        store.capture(text: "second", sourceApplication: nil)

        store.promote(store.items[1])

        XCTAssertEqual(store.items.map(\.text), ["first", "second"])
    }

    func testMaximumItemCountTrimsOlderItems() {
        let store = makeStore()
        store.maximumItemCount = 10
        for index in 0..<12 {
            store.capture(text: "item \(index)", sourceApplication: nil)
        }

        XCTAssertEqual(store.items.count, 10)
        XCTAssertEqual(store.items.first?.text, "item 11")
        XCTAssertEqual(store.items.last?.text, "item 2")
    }

    func testCaptureCanBeDisabled() {
        let store = makeStore()
        store.isCaptureEnabled = false

        store.capture(text: "private", sourceApplication: nil)

        XCTAssertTrue(store.items.isEmpty)
    }

    func testWhitespaceIsPreservedExactly() {
        let store = makeStore()
        let text = "\n  hello 👋\t\n\n"
        store.capture(text: text, sourceApplication: nil)
        XCTAssertEqual(store.items.first?.text, text)
    }

    func testRetentionBoundsDoNotRecurse() {
        let store = makeStore()
        store.maximumItemCount = -10
        XCTAssertEqual(store.maximumItemCount, 10)
        store.maximumItemCount = 2_000
        XCTAssertEqual(store.maximumItemCount, 1_000)
    }

    func testDeleteAndClear() {
        let store = makeStore()
        store.capture(text: "one", sourceApplication: nil)
        store.capture(text: "two", sourceApplication: nil)
        store.delete(store.items[1])
        XCTAssertEqual(store.items.map(\.text), ["two"])
        store.clear()
        XCTAssertTrue(store.items.isEmpty)
    }

    func testPersistenceAtPathContainingSpaces() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Remember This Tests \(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let persister = FileClipboardHistoryPersister(fileURL: directory.appendingPathComponent("history.json"))
        XCTAssertTrue(try persister.load().isEmpty)
        let items = [ClipboardItem(text: "\nhello\t")]
        try persister.save(items)
        XCTAssertEqual(try persister.load(), items)
        let preferences = UserDefaults(suiteName: "RememberThisTests.\(UUID().uuidString)")!
        XCTAssertEqual(ClipboardHistoryStore(persister: persister, preferences: preferences).items, items)
    }

    private func makeStore() -> ClipboardHistoryStore {
        let preferences = UserDefaults(suiteName: "RememberThisTests.\(UUID().uuidString)")!
        return ClipboardHistoryStore(persister: InMemoryPersister(), preferences: preferences)
    }
}

private final class InMemoryPersister: ClipboardHistoryPersisting {
    private var items: [ClipboardItem] = []

    func load() throws -> [ClipboardItem] { items }

    func save(_ items: [ClipboardItem]) throws {
        self.items = items
    }
}
