# Local-network discovery

Paired desktop receivers advertise a Bonjour/mDNS service. Discovery is only a
way to find an endpoint: a sender must authenticate the receiver against the
public key stored during QR pairing before sending any user content.

The service type, transport, and cryptographic handshake are deliberately not
yet frozen. Define them here before an implementation lands, then add the exact
records and interoperability fixtures under `fixtures/`.
