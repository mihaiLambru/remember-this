# Local sharing implementation plan

## Components

| Component | Responsibility |
| --- | --- |
| macOS menu-bar receiver | Starts at login, owns key material, Bonjour listener, WSS endpoint, transfer validation, clipboard writes, and incoming-file storage. It is unavailable when not running. |
| macOS pairing/settings UI | Shows/cancels expiring QR invitations; lists paired iPhones; revokes pairing; opens the Incoming folder. |
| iOS app | Owns phone identity and pairing store; scans QR; browses paired Macs; reports discovery and transfer state. |
| iOS Share extension | Extracts one text/image/file share, enumerates reachable paired Macs, has the user choose one, and sends only while local delivery can complete. |
| Shared protocol package | Owns the Protobuf schemas, deterministic-signature rules, protocol fixtures, limits, and conformance tests. |

The receiver runs at login as the user through the normal macOS Login Item /
Launch-at-login mechanism. It does not attempt to run while the Mac is logged
out. On iOS, neither the main app nor a share extension can promise an always-on
listener; iOS is a sender in v1. The Share extension must finish within iOS's
execution budget and report an unavailable/failed transfer rather than using a
server queue.

## Milestones

1. **Protocol foundation:** freeze these schemas and fixtures; implement strict
   bounds validation, deterministic signing bytes, and keychain pairing records.
2. **Mac receiver:** add the background/menu-bar lifecycle, locally generated
   TLS identity, Bonjour advertisement, pinned WSS listener, and a status view.
3. **QR pairing:** add invitation generation/expiry, native QR presentation,
   iOS camera scan, QR validation, pairing exchange, and paired-device revoke
   controls on both platforms.
4. **Authenticated sessions:** implement the session handshake, pin validation,
   error states, reconnection only through fresh Bonjour discovery, and audit
   logging with secret redaction.
5. **Text and image delivery:** add iOS Share extension extraction, selectable
   reachable Macs, offers/receipts, and validated `NSPasteboard` writes.
6. **File delivery:** stream up to 100 MiB in bounded chunks to a temporary
   app-controlled location, SHA-256 verify, atomically commit, and expose the
   local destination in the Mac UI.
7. **Hardening and release readiness:** run interoperability, network-failure,
   performance, accessibility, privacy-manifest, entitlements, and manual
   physical-device tests before shipping.

## Required product states

Expose these states in the sender/receiver UI: `paired`, `discovering`,
`reachable`, `connecting`, `transferring`, `unavailable`, and `failed`. The
Share extension must say why a Mac is unavailable where known (not on local
network, receiver not running, local-network permission denied, or secure
connection rejected) without exposing security-sensitive diagnostics.

## Test matrix

| Scenario | Expected evidence |
| --- | --- |
| QR pairing succeeds | Both Keychains contain reciprocal pairing records; secret cannot pair a second time. |
| Expired/altered QR | Phone rejects before pairing record creation. |
| Phone paired with several Macs | Each has distinct ID/pin; Share extension lists only currently reachable targets. |
| IP/port/Wi-Fi change on same LAN | Bonjour rediscovery finds the stored trusted identity; no endpoint is persisted. |
| Guest network/client isolation/VPN | Clear `unavailable` state; no Internet fallback or content leak. |
| Rogue Bonjour service / wrong certificate | No content leaves the iPhone; pin failure is visible as secure-connection failure. |
| Replayed requests/sessions/transfers | Pair/session rejected; a duplicate transfer causes no second clipboard/file side effect. |
| Text/image delivery | Hash/size verified, then exactly one `NSPasteboard` write and receipt. |
| Files at 99 MiB, 100 MiB, 100 MiB + 1 byte | First two accepted if valid; over-limit offer/stream rejected and temp data removed. |
| Interrupted/corrupt transfer | No final file or clipboard update; temporary data removed. |
| Revoked device | Active session closes; future discovery never becomes authorized. |
| Receiver stopped | Sender displays unavailable and does not queue/retry via cloud. |

Physical-device testing is mandatory for Bonjour, local-network permissions,
camera scanning, share-extension lifecycle, Keychain accessibility, clipboard
behavior, and login-item behavior; simulators alone are insufficient.

## Apple-platform risks to resolve before implementation

- Confirm the chosen signing and TLS key configuration is supported by both
  `CryptoKit`/Security and `Network.framework` on the minimum iOS/macOS versions.
- Add the iOS local-network privacy usage description and Bonjour service type
  entries; add any required macOS sandbox/network entitlements.
- Establish the Share extension's App Group only for short-lived handoff data,
  never for plaintext long-term keys or transfer payload retention.
- Validate whether the app's chosen login-item approach is appropriate for its
  distribution channel and minimum macOS version.
- Decide and document the initial MIME allow-list before accepting non-text
  payloads; do not infer safety from an extension alone.
