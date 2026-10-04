# Protocol fixtures

Add interoperable QR payloads, pairing requests, and transfer metadata here.
Every client implementation should run these fixtures unchanged. Fixtures use
generated test keys only and must never contain production secrets or private
keys.

Cover deterministic QR encoding, pairing/session signing bytes, valid and
invalid 100 MiB boundary offers, and malformed or out-of-order chunks. Every
fixture names the protocol major version and expected acceptance or rejection.
