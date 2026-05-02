# TextSnipper

TextSnipper is an open-source native macOS app for quickly capturing text from the screen.

> Status: Early open-source build.

## Download

Download the latest macOS build from the GitHub Releases page.

## Install on macOS

This app is open source and currently not Apple-notarized.
Because it is not signed with an Apple Developer ID, macOS may block it the first time you open it.

### Steps

1. Download `TextSnipper-macOS.zip`.
2. Unzip the file.
3. Move `TextSnipper.app` to the Applications folder.
4. Right-click `TextSnipper.app`.
5. Click **Open**.
6. If macOS blocks the app:
   - Open **System Settings**
   - Go to **Privacy & Security**
   - Scroll down to the security section
   - Click **Open Anyway**
   - Confirm

## Build from source

Requirements:
- macOS
- Xcode
- Git

Clone the project:

```bash
git clone https://github.com/YOUR_USERNAME/TextSnipper.git
cd TextSnipper
```

Build:

```bash
./scripts/package-macos-open-source.sh
```

The release file will be created at:

`release/TextSnipper-macOS.zip`

## Development

Open the project in Xcode:

```bash
open TextSnipper.xcodeproj
```

Run the app with:

`Cmd + R`

## macOS security notice

TextSnipper is currently open source and not Apple-notarized.
macOS may show a warning because this build is not signed with an Apple Developer ID.

You can either:
1. Build the app from source, or
2. Manually approve the downloaded app in System Settings -> Privacy & Security -> Open Anyway.

Do not disable Gatekeeper globally.

## License

MIT License.
