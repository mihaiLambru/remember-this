import Foundation

public struct ClipboardItem: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let text: String
    public let createdAt: Date
    public let sourceApplication: String?

    public init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = .now,
        sourceApplication: String? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.sourceApplication = sourceApplication
    }

    public var preview: String {
        text.replacingOccurrences(of: "\n", with: " ")
    }
}
