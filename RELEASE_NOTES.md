# TextSnipper 1.0.0

Initial public release of TextSnipper for macOS.

## Highlights

- Capture text from any selected screen region.
- Detect QR codes and copy their payload to the clipboard.
- Fast local OCR powered by Apple's Vision framework.
- Fully offline processing with no analytics or network requests.
- Menu bar workflow after first-run setup.
- Escape cancels selection or long-running snip work.
- Settings recovery when the menu bar icon is hidden: press the snip shortcut, then `Command + ,` while the overlay is visible.
- Native screenshot-style selection cursor.
- Clear permission indicators for Screen Recording and Accessibility.

## Install

1. Download `TextSnipper-macOS.zip`.
2. Unzip it.
3. Move `TextSnipper.app` to Applications.
4. Right-click the app and choose **Open** the first time.

TextSnipper is currently unsigned and not notarized. macOS may require approving the app from **System Settings -> Privacy & Security -> Open Anyway**.

### If macOS says the app is "damaged"

Recent macOS versions show a "damaged and can't be opened" message for any unsigned app downloaded from the internet. The app is fine — it's the quarantine flag macOS adds to downloads. Remove it once with:

```sh
xattr -dr com.apple.quarantine /Applications/TextSnipper.app
```

Then open the app normally. You only need to run this once after first install.

## License

TextSnipper is source-available for non-commercial use. Commercial resale or paid redistribution requires written permission from Mohamed Rafiq.
