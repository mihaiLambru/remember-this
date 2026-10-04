# Local discovery and transport (v1)

Remember This is **LAN-only**. It has no relay, cloud service, account service,
or remote fallback. Bonjour merely finds a possible receiver; it never grants
that receiver trust.

## Bonjour advertisement

The macOS menu-bar receiver owns one `NWListener` using
`NWParameters(tls:tcp:)` with `NWProtocolWebSocket.Options`. It advertises:

| Field | Value |
| --- | --- |
| DNS-SD type | `_rememberthis._tcp` |
| Domain | `local.` |
| Transport | TLS 1.3 over TCP, WebSocket binary messages (`wss`) |
| Service name | a human-readable Mac name plus a collision-safe suffix |
| Port | assigned by the listener; never persisted by a phone |
| TXT `v` | protocol major version (`1`) |
| TXT `id` | stable receiver UUID, encoded as lowercase hexadecimal |
| TXT `fp` | base64url SHA-256 of the receiver TLS certificate SPKI |

`id` and `fp` are public discovery hints, not credentials. The receiver must
withdraw the advertisement when stopped. It must not advertise a pairing secret,
key material, a full device roster, file details, or a routable address in TXT.

On iOS, `NWBrowser` searches `_rememberthis._tcp` on `.local`. A sender only
offers an endpoint for a stored pairing when its TXT `id` and `fp` match that
pairing. It still validates the certificate pin during TLS setup. A changed
address or port is normal; a changed fingerprint is a security failure, not an
automatic re-pair.

Discovery can fail on guest networks, client/AP isolation, multicast-filtering
networks, and some VPN configurations. The product state in those cases is
`unavailable`, with the explanation that both devices must be reachable on the
same local network. There is deliberately no Internet fallback.

## TLS and WebSocket

The listener uses a locally generated, self-signed TLS certificate. The
certificate private key stays in macOS Keychain. iOS accepts it only when its
SPKI SHA-256 pin equals the fingerprint saved in a completed QR pairing. Use
TLS 1.3 and reject invalid chains, hostname-only trust, TLS versions below 1.3,
and certificate-pin changes.

The WebSocket path is `/v1/pair` for the one-time pairing exchange and
`/v1/session` for normal transfers. It accepts binary Protobuf envelopes only;
reject text frames, compression, and frames above 1 MiB. File bodies use a
separate binary chunk frame described below.

TLS protects transport confidentiality. The authenticated protocol below is
also mandatory: it makes a valid local TLS endpoint insufficient to send or
receive content.

## Pairing protocol

Each app has two long-lived per-device identities generated locally: an Ed25519
signing key for protocol authentication, and a TLS certificate/key pair for the
Mac receiver.

The QR payload is deterministic `PairingInvitation` Protobuf encoding, base64url
without padding inside `rememberthis://pair?d=...`. It is shown only while the
receiver has an in-memory pairing record. The 32-byte secret is generated with
`SecRandomCopyBytes`, expires after 5 minutes, and is deleted after its first
successful use, expiry, receiver restart, or explicit cancel. It is never
written to disk or logs.

1. The iPhone scans and validates the invitation: version 1, UUID, exact field
   lengths, unexpired time, and a 32-byte secret.
2. It browses Bonjour until it finds the advertised receiver ID, then opens
   `wss://endpoint/v1/pair`, pinning the QR fingerprint before sending a frame.
3. It generates a random 32-byte request ID and nonce and sends
   `PairingRequest`. Its Ed25519 signature covers the UTF-8 domain separator
   `remember-this/pair-request/v1` followed by deterministic Protobuf bytes of
   every request field except `signature`.
4. The Mac verifies the secret and expiry, field bounds, request signature, and
   that the request ID has never been used. It atomically consumes the
   invitation, saves the iPhone public key and metadata, then returns a signed
   `PairingResult`; its signature uses the same scheme with domain separator
   `remember-this/pair-result/v1`.
5. The iPhone verifies the receiver identity and signature against the QR key,
   then stores the receiver ID, signing key, TLS SPKI pin, name, and pairing ID.

If any step fails, neither side creates a usable pairing. A partially written
record must be deleted. Scanning an expired or used QR requires showing a new
one on the Mac.

## Normal-session authentication

After TLS pinning, a peer must complete this exchange before any transfer:

1. Client sends `SessionHello` with its pairing ID and a fresh 32-byte nonce.
2. Receiver responds with `SessionChallenge`, including a fresh 32-byte nonce
   and a random session ID.
3. Client sends `SessionAuthenticate`, an Ed25519 signature over UTF-8 domain
   separator `remember-this/session-client/v1`, then session ID, client nonce,
   receiver nonce, and pairing ID in that exact order.
4. Receiver verifies the signature using the stored paired-phone key and sends
   `SessionAccepted` signed with `remember-this/session-receiver/v1` followed
   by the same four values in the same order.

Nonces and session IDs are single-use in memory. Each side enforces a 30-second
handshake deadline and closes on invalid, duplicate, out-of-order, or unexpected
messages. Application authorization derives only from the stored pairing ID and
key, never from Bonjour name, IP address, or a claimed device name.

## Transfer frames

After `SessionAccepted`, the iPhone sends `TransferOffer`. The receiver checks
pairing authorization, supported kind, MIME type, filename sanitization, and
`byte_count <= 104857600` (100 MiB) before replying with `TransferDecision`.
Only an accepted offer may send content.

- Text: one `TransferPayload` Protobuf message, UTF-8, at most 1 MiB.
- Image/file: binary chunks; the final SHA-256 must match the offer.

Each chunk is a binary WebSocket frame: `RTCH` (4 bytes), version (1 byte),
transfer UUID (16 bytes), zero-based chunk index (8-byte big-endian), then up
to 256 KiB payload. Chunks must arrive strictly in order. The receiver counts
bytes while streaming, rejects counts beyond the offer or 100 MiB, hashes the
content, and deletes the temporary file on disconnect, timeout, ordering error,
hash mismatch, or rejection. It atomically moves an accepted file to
`Application Support/Remember This/Incoming` only after validation. Text and
images are written to `NSPasteboard` only after successful integrity validation.
The receiver returns `TransferReceipt`.

Duplicate transfer IDs are idempotent for 24 hours: return the original receipt
without applying clipboard or filesystem side effects again.
