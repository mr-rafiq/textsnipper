# TextSnipper 1.2.0

TextSnipper 1.2.0 focuses on faster default OCR, optional extended language support, clipboard history, and clearer copy feedback.

## Highlights

- Fast default OCR for Apple Vision-supported languages.
- Optional Indian and Asian script OCR via local Tesseract language data.
- Clipboard history popup with `Option + Command + C`.
- Select a clipboard history item to paste it into the active app.
- Clipboard history can be cleared or disabled in Settings.
- Green bottom-center copied confirmation after successful snips.
- More reliable clipboard history popup behavior from the menu bar and global shortcut.
- Fully offline processing with no analytics or network requests.

## OCR Support

Default OCR uses Apple's local Vision framework for supported languages such as English, Spanish, French, German, Italian, Portuguese, Chinese, Japanese, Korean, and more.

Optional OCR support for scripts such as Tamil and Hindi can be enabled in Settings after installing Tesseract language data. Optional Indian and Asian OCR may take a little longer to copy than the default Apple Vision path.

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
