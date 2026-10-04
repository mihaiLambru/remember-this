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

The schemas are Protobuf so Swift, Kotlin, Rust, and test tooling can generate
types from one source of truth. Version 1 uses Bonjour discovery plus pinned TLS
WebSockets and has no server component.

- [Discovery, transport, pairing, and transfer rules](discovery.md)
- [Security and threat model](security.md)
- [Implementation milestones, tests, and platform risks](implementation-plan.md)
