# Remember This

Remember This is a native, local-first companion suite. This repository contains
the desktop apps, mobile sender apps, and their shared transfer protocol.

## Repository layout

- `apps/macos` — the existing macOS clipboard-history application.
- `apps/ios/RememberThisIOS` — a native iOS application shell. It currently
  launches an empty activity and is ready for the pairing and Share extension
  work.
- `packages/protocol` — language-neutral contracts for pairing, discovery, and
  local-network transfers.

## Development

### macOS

```sh
cd apps/macos
swift test
bash scripts/package-app.sh 0.1.0
```

### iOS

Open `apps/ios/RememberThisIOS/RememberThisIOS.xcodeproj` in Xcode, select an
iOS Simulator or device, and run the `RememberThisIOS` scheme. The starter app
does not need signing to build for the simulator.

## Continuous delivery

GitHub Actions builds and uploads both the macOS archive and an unsigned iOS
Simulator app archive on pushes and pull requests. Pushing a `vX.Y.Z` tag also
creates a GitHub release with both artifacts. App Store or TestFlight delivery
will be added once the Apple Developer signing and App Store Connect credentials
are available.
