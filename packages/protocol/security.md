# Security and threat model (v1)

## Trust boundary

The local network is hostile. A user may trust a Mac after scanning its QR code;
they do not trust every device that can advertise Bonjour records or accept TCP
connections. TLS 1.3 plus the QR-bound SPKI pin protects the receiver endpoint.
The signed pairing and session handshakes protect authorization. Both are
required.

| Threat | Required control |
| --- | --- |
| Rogue Bonjour advertisement or DNS-SD spoofing | Match stored receiver ID and pin the QR/stored TLS SPKI fingerprint before application data. |
| Man-in-the-middle during first pairing | QR binds the expected Mac signing key, TLS pin, one-time secret, and expiry; the phone refuses a mismatching endpoint. |
| Replayed pairing request | 5-minute one-time secret, request ID replay cache, atomic invitation consumption, and signed fresh nonce. |
| Replayed normal session | 32-byte client/receiver nonces, random session ID, signatures over all values, one-use in-memory cache, 30-second deadline. |
| Stolen old QR image | Expiry, receiver restart invalidation, one-time use, and no durable secret. |
| Lost or compromised phone/Mac | Either side can revoke the pairing. The receiver immediately closes active sessions and rejects future pairing IDs. Re-pairing requires a new QR scan. |
| TLS certificate/key rotation | Pin change is fail-closed. Present an explicit re-pair flow; never silently update a pin through discovery. |
| Unauthorized or oversized upload | Authenticated pairing required before offer; 100 MiB hard ceiling before and during stream; allow-listed types and bounded metadata. |
| Path traversal / malicious files | Ignore directory components, generate destination names, use temporary app-controlled files, atomic commit after hash verification, never execute/open automatically. |
| Clipboard injection through transfer replay | Transfer-ID idempotency cache prevents duplicate side effects for 24 hours. |
| Data leakage through diagnostics | Redact payloads, secrets, tokens, keys, certificate data, exact filenames, and endpoint addresses from production logs. |

## Key storage and lifecycle

Use Keychain records for all private signing keys, TLS keys, TLS pins, peer
public keys, and pairing IDs. On iOS use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
for receiver-needed material; use stronger user-presence protection only if it
does not prevent the promised automatic local delivery. On macOS use Keychain
with an app-specific access group and no plaintext exports. Prefer Secure
Enclave-backed keys where the chosen key algorithm and TLS integration support
them, while keeping the protocol compatible with devices where they do not.

Never sync pairing secrets or private identity keys through iCloud Keychain.
Persist only a pairing record containing peer public identity, receiver pin,
pairing ID, display name, creation time, and revocation status. Delete all of it
on unpair. Generate a new receiver TLS certificate only through an explicit
rotation/re-pair process.

## Security decisions to keep explicit

- No automatic trust migration on key, certificate, or device-ID change.
- No pairing through a manually typed IP address in v1; it bypasses the stated
  local discovery product boundary and makes user verification weaker.
- No remote queue, retry server, analytics payload capture, or cloud backup of
  transferred content.
- No automatic execution, preview process, or Finder reveal of incoming files.
- Security review is required before supporting additional MIME types,
  resumable transfers, background wake behavior, or cross-network delivery.
