# Remember This protocol

This package owns the language-neutral contract used by every Remember This
client. It is intentionally independent of any UI implementation.

## Versioning

The protocol uses semantic versions. A client must reject a peer whose major
version it does not support. Additive, backward-compatible fields are minor
version changes.

## Initial scope

- QR-initiated device pairing
- trusted local-network discovery
- encrypted transfer of text, images, and files

The schemas are Protobuf so Swift, Kotlin, Rust, and server tooling can generate
types from one source of truth. Transport, encryption, and discovery details are
specified in `discovery.md`; they will be finalized before the first pairing UI
is implemented.
