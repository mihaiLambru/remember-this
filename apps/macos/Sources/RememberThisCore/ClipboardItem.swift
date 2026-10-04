import Foundation

public struct ClipboardItem: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let text: String
    public let attachments: [ClipboardAttachment]
    public let createdAt: Date
    public let sourceApplication: String?

    public init(
        id: UUID = UUID(),
        text: String = "",
        attachments: [ClipboardAttachment] = [],
        createdAt: Date = .now,
        sourceApplication: String? = nil
    ) {
        self.id = id
        self.text = text
        self.attachments = attachments
        self.createdAt = createdAt
        self.sourceApplication = sourceApplication
    }

    public var preview: String {
        if !text.isEmpty {
            return text.replacingOccurrences(of: "\n", with: " ")
        }
        if attachments.count == 1, let attachment = attachments.first {
            return attachment.filename
        }
        return "\(attachments.count) attachments"
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, attachments, createdAt, sourceApplication
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        text = try values.decode(String.self, forKey: .text)
        attachments = try values.decodeIfPresent([ClipboardAttachment].self, forKey: .attachments) ?? []
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        sourceApplication = try values.decodeIfPresent(String.self, forKey: .sourceApplication)
    }
}

public struct ClipboardAttachment: Codable, Identifiable, Hashable, Sendable {
    public enum Storage: Codable, Hashable, Sendable {
        /// A sandbox-safe bookmark to the source file. This is preferred so files stay in place.
        case originalFile(bookmark: Data)
        /// A private copy used for image-only clipboard data or when a bookmark cannot be made.
        case localCopy(relativePath: String)
    }

    public let id: UUID
    public let filename: String
    public let contentType: String?
    public let byteCount: Int64
    public let storage: Storage

    public init(
        id: UUID = UUID(),
        filename: String,
        contentType: String? = nil,
        byteCount: Int64,
        storage: Storage
    ) {
        self.id = id
        self.filename = filename
        self.contentType = contentType
        self.byteCount = byteCount
        self.storage = storage
    }

    public var isImage: Bool {
        contentType?.hasPrefix("image/") == true
    }
}
