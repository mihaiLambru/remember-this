import Foundation
import UniformTypeIdentifiers

public enum ClipboardAttachmentError: LocalizedError, Equatable {
    case exceedsMaximumSize(filename: String, maximumBytes: Int64)
    case unreadableFile(URL)

    public var errorDescription: String? {
        switch self {
        case let .exceedsMaximumSize(filename, maximumBytes):
            return "\(filename) exceeds the \(maximumBytes / 1_000_000) MB attachment limit."
        case let .unreadableFile(url):
            return "\(url.lastPathComponent) could not be read."
        }
    }
}

/// Owns local fallback copies while allowing normal files to remain in their original locations.
public final class ClipboardAttachmentStore: @unchecked Sendable {
    public static let maximumAttachmentBytes: Int64 = 100 * 1_000_000

    public let directoryURL: URL
    private let fileManager: FileManager
    private let bookmarkDataProvider: (URL) throws -> Data

    public init(
        directoryURL: URL,
        fileManager: FileManager = .default,
        bookmarkDataProvider: @escaping (URL) throws -> Data = { url in
            try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        }
    ) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        self.bookmarkDataProvider = bookmarkDataProvider
    }

    public convenience init(fileManager: FileManager = .default) {
        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.init(directoryURL: supportDirectory
            .appending(path: "RememberThis", directoryHint: .isDirectory)
            .appending(path: "Clipboard Attachments", directoryHint: .isDirectory), fileManager: fileManager)
    }

    public func captureFile(at url: URL, maximumBytes: Int64 = maximumAttachmentBytes) throws -> ClipboardAttachment {
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey, .isRegularFileKey])
        } catch {
            throw ClipboardAttachmentError.unreadableFile(url)
        }
        guard values.isRegularFile != false, let fileSize = values.fileSize else {
            throw ClipboardAttachmentError.unreadableFile(url)
        }
        let byteCount = Int64(fileSize)
        guard byteCount <= maximumBytes else {
            throw ClipboardAttachmentError.exceedsMaximumSize(filename: url.lastPathComponent, maximumBytes: maximumBytes)
        }

        let contentType = values.contentType?.preferredMIMEType
        do {
            let bookmark = try bookmarkDataProvider(url)
            return ClipboardAttachment(
                filename: url.lastPathComponent,
                contentType: contentType,
                byteCount: byteCount,
                storage: .originalFile(bookmark: bookmark)
            )
        } catch {
            return try makeLocalCopy(from: url, contentType: contentType, byteCount: byteCount)
        }
    }

    public func captureImageData(
        _ data: Data,
        filename: String,
        contentType: String = "image/png",
        maximumBytes: Int64 = maximumAttachmentBytes
    ) throws -> ClipboardAttachment {
        guard Int64(data.count) <= maximumBytes else {
            throw ClipboardAttachmentError.exceedsMaximumSize(filename: filename, maximumBytes: maximumBytes)
        }
        try ensureDirectory()
        let relativePath = uniqueRelativePath(filename: filename)
        try data.write(to: directoryURL.appending(path: relativePath), options: .atomic)
        return ClipboardAttachment(filename: filename, contentType: contentType, byteCount: Int64(data.count), storage: .localCopy(relativePath: relativePath))
    }

    public func withResolvedURL<T>(for attachment: ClipboardAttachment, perform: (URL) throws -> T) rethrows -> T? {
        switch attachment.storage {
        case let .localCopy(relativePath):
            let url = directoryURL.appending(path: relativePath)
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return try perform(url)
        case let .originalFile(bookmark):
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { return nil }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            return try perform(url)
        }
    }

    private func makeLocalCopy(from sourceURL: URL, contentType: String?, byteCount: Int64) throws -> ClipboardAttachment {
        try ensureDirectory()
        let relativePath = uniqueRelativePath(filename: sourceURL.lastPathComponent)
        let destinationURL = directoryURL.appending(path: relativePath)
        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw ClipboardAttachmentError.unreadableFile(sourceURL)
        }
        return ClipboardAttachment(filename: sourceURL.lastPathComponent, contentType: contentType, byteCount: byteCount, storage: .localCopy(relativePath: relativePath))
    }

    private func ensureDirectory() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func uniqueRelativePath(filename: String) -> String {
        "\(UUID().uuidString)-\(filename)"
    }
}
