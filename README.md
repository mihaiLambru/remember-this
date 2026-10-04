# Remember This

Remember This is a small macOS clipboard-history app for plain text.

## Privacy

The project is local-only by design. Clipboard history stays on the device: there are no accounts, analytics, network requests, or cloud sync.

## Current features

- A main window for browsing clipboard history and opening Settings.
- A global `⌘⇧V` picker for choosing a previous item.
- Selected items become the active macOS clipboard, ready for the normal `⌘V` paste shortcut.

## Development

```sh
swift test
bash scripts/package-app.sh 0.1.0
```

The packaging command produces a locally ad-hoc-signed app and a ZIP archive in `dist/`.

## Releases

Push a tag named `vX.Y.Z` to run tests, build a ZIP, and create a GitHub release. The generated archive is not notarized; Mac App Store distribution will require a final bundle identifier, Apple distribution signing, and notarization where applicable.
