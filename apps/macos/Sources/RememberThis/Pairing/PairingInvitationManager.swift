import AppKit
import Combine
import CoreImage
import CryptoKit
import Foundation
import Security

@MainActor
final class PairingInvitationManager: ObservableObject {
    @Published private(set) var invitation: PairingInvitation?

    private let keychain = PairingKeychain()
    private var expiryTimer: Timer?

    func createInvitation() {
        let receiverID = keychain.loadOrCreateDeviceID()
        let signingPublicKey = keychain.loadOrCreateSigningPublicKey()
        let tlsPin = keychain.loadOrCreateTLSPin()
        let secret = Self.randomBytes(count: 32)
        let expiration = Date().addingTimeInterval(5 * 60)
        let payload = PairingInvitationPayload(
            receiverID: receiverID,
            signingPublicKey: signingPublicKey,
            tlsSPKISHA256: tlsPin,
            secret: secret,
            expiresAt: expiration
        )

        invitation = PairingInvitation(
            qrImage: Self.makeQRCode(for: payload.uri),
            expiresAt: expiration
        )
        scheduleExpiry(at: expiration)
    }

    func clearInvitation() {
        invitation = nil
        expiryTimer?.invalidate()
        expiryTimer = nil
    }

    private func scheduleExpiry(at expiration: Date) {
        expiryTimer?.invalidate()
        expiryTimer = Timer.scheduledTimer(withTimeInterval: max(expiration.timeIntervalSinceNow, 0), repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.invitation = nil
            }
        }
    }

    private static func makeQRCode(for string: String) -> NSImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage?.transformed(by: .init(scaleX: 10, y: 10)) else { return nil }
        let representation = NSCIImageRep(ciImage: output)
        let image = NSImage(size: representation.size)
        image.addRepresentation(representation)
        return image
    }

    private static func randomBytes(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        precondition(SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess)
        return Data(bytes)
    }
}

struct PairingInvitation {
    let qrImage: NSImage?
    let expiresAt: Date
}

private struct PairingInvitationPayload {
    let receiverID: UUID
    let signingPublicKey: Data
    let tlsSPKISHA256: Data
    let secret: Data
    let expiresAt: Date

    var uri: String {
        let encoded = protobufData().base64URLEncodedString()
        return "rememberthis://pair?d=\(encoded)"
    }

    // Matches rememberthis.protocol.v1.PairingInvitation without requiring a
    // generated Protobuf target in this early macOS package.
    private func protobufData() -> Data {
        var data = Data()
        data.appendVarintField(number: 1, value: 1)
        data.appendLengthDelimitedField(number: 2, value: Data(receiverID.uuidString.lowercased().utf8))
        data.appendLengthDelimitedField(number: 3, value: signingPublicKey)
        data.appendLengthDelimitedField(number: 4, value: tlsSPKISHA256)
        data.appendLengthDelimitedField(number: 5, value: secret)
        data.appendVarintField(number: 6, value: UInt64(expiresAt.timeIntervalSince1970))
        return data
    }
}

private final class PairingKeychain {
    private let service = "com.rememberthis.app.pairing"

    func loadOrCreateDeviceID() -> UUID {
        if let value = read(account: "device-id"), let string = String(data: value, encoding: .utf8), let id = UUID(uuidString: string) {
            return id
        }
        let id = UUID()
        save(Data(id.uuidString.lowercased().utf8), account: "device-id")
        return id
    }

    func loadOrCreateSigningPublicKey() -> Data {
        if let privateKeyData = read(account: "ed25519-private-key"), let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData) {
            return privateKey.publicKey.rawRepresentation
        }
        let privateKey = Curve25519.Signing.PrivateKey()
        save(privateKey.rawRepresentation, account: "ed25519-private-key")
        return privateKey.publicKey.rawRepresentation
    }

    // The receiver's TLS listener is the next implementation milestone. Keeping
    // its advertised pin in Keychain now gives the QR invitation a stable field
    // and avoids ever placing key material in UserDefaults or the QR image.
    func loadOrCreateTLSPin() -> Data {
        if let pin = read(account: "tls-spki-sha256"), pin.count == 32 { return pin }
        var bytes = [UInt8](repeating: 0, count: 32)
        precondition(SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess)
        let pin = Data(bytes)
        save(pin, account: "tls-spki-sha256")
        return pin
    }

    private func read(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    private func save(_ data: Data, account: String) {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            let update = [kSecValueData as String: data]
            precondition(SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecSuccess)
        } else {
            precondition(status == errSecSuccess)
        }
    }
}

private extension Data {
    mutating func appendVarintField(number: UInt64, value: UInt64) {
        appendVarint((number << 3) | 0)
        appendVarint(value)
    }

    mutating func appendLengthDelimitedField(number: UInt64, value: Data) {
        appendVarint((number << 3) | 2)
        appendVarint(UInt64(value.count))
        append(value)
    }

    mutating func appendVarint(_ value: UInt64) {
        var remaining = value
        while remaining >= 0x80 {
            append(UInt8(remaining & 0x7f) | 0x80)
            remaining >>= 7
        }
        append(UInt8(remaining))
    }

    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
