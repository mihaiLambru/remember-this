# Remember This for iOS

This is the native iOS companion app. It intentionally starts as an empty
SwiftUI activity while pairing, local-network transfer, and the Share extension
are developed.

## Build

Open `RememberThisIOS.xcodeproj` in Xcode and run the `RememberThisIOS` scheme,
or build a simulator binary from the command line:

```sh
xcodebuild build \
  -project RememberThisIOS.xcodeproj \
  -scheme RememberThisIOS \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO
```
