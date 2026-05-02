# TextSnipper

TextSnipper is a macOS menu bar utility that lets you snip any screen region, run OCR, detect QR payloads, and copy the result directly to the clipboard.

## Features

- Global shortcut (default: `Shift + Command + 2`) to start snipping.
- Region-based screen capture.
- OCR using Apple Vision.
- QR detection and payload extraction.
- Clipboard-first workflow.
- Minimal menu bar UI with settings.
- Fully offline processing.

## Requirements

- macOS with ScreenCaptureKit support.
- Xcode 16+ recommended.

## Permissions

TextSnipper requires:

- Screen Recording permission (for screen snips).
- Accessibility permission (for global hotkey behavior).

The app shows onboarding to help grant both permissions.

## Usage

1. Launch TextSnipper.
2. Grant required permissions when prompted.
3. Press `Shift + Command + 2`.
4. Drag to select a region.
5. Recognized text (or QR payload) is copied to clipboard.

## Settings

Open from menu bar:

- Toggle menu bar icon visibility.
- Change launch-at-login preference.
- Configure hotkey.
- Open system permission pages.

## Development

Project entrypoint:

- `TextSnipper/TextSnipper/TextSnipperApp.swift`

Key components:

- `ScreenCaptureService.swift` (screen capture)
- `OCRPipeline.swift` (OCR + QR extraction)
- `GlobalHotkeyManager.swift` (global shortcut)
- `SnippingOverlay.swift` (selection overlay)
- `PreferencesView.swift` (settings UI)

## License

Add your preferred open-source license (for example MIT) in a `LICENSE` file.
