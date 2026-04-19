# LocalSend USB

Small macOS SwiftUI helper app for rebuilding `adb reverse` and launching LocalSend for USB-based transfers.

## Requirements

- macOS 14+
- LocalSend installed on the Mac
- `adb` installed on the Mac and available via `which adb`
- Android device with USB debugging enabled

Install `adb` with:

```bash
brew install android-platform-tools
```

## Build

```bash
./build_app.sh
```

The built app is written to:

```bash
dist/LocalSend USB.app
```

## Included Files

- `origin-command/localsend-usb.command`: original shell-script workflow
- `LocalSendUSBApp.swift`, `ContentView.swift`, `SetupRunner.swift`: SwiftUI app source
- `resources/Info.plist`: app bundle metadata
- `scripts/GenerateIcon.swift`: icon generator used by the build script
