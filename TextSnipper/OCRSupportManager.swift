// OCRSupportManager.swift
// Checks and installs optional local OCR dependencies for additional scripts.

import AppKit
import Combine
import Foundation

struct OCRSupportStatus: Equatable {
    var hasHomebrew = false
    var hasTesseract = false
    var hasTamil = false
    var hasHindi = false

    var isReadyForIndianLanguages: Bool {
        hasTesseract && hasTamil && hasHindi
    }
}

@MainActor
final class OCRSupportManager: ObservableObject {
    @Published private(set) var status = OCRSupportStatus()

    init() {
        refresh()
    }

    func refresh() {
        let installedLanguageCodes = Self.installedLanguageCodes()
        status = OCRSupportStatus(
            hasHomebrew: Self.homebrewExecutableURL() != nil,
            hasTesseract: Self.tesseractExecutableURL() != nil,
            hasTamil: installedLanguageCodes.contains("tam"),
            hasHindi: installedLanguageCodes.contains("hin")
        )
    }

    func openInstaller() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.installCommand, forType: .string)
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
        showInstallInstructions()
    }

    private func showInstallInstructions() {
        let alert = NSAlert()
        alert.messageText = "Install command copied"
        alert.informativeText = "Terminal is open. Paste the copied command and press Return to install Homebrew, Tesseract, and Tamil/Hindi OCR data."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    nonisolated private static let installCommand = """
    if ! command -v brew >/dev/null 2>&1; then NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; fi; if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi; brew install tesseract tesseract-lang; tesseract --list-langs | grep -E '^(tam|hin)$'
    """

    nonisolated private static func homebrewExecutableURL() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew"
        ]

        return candidates
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    nonisolated private static func tesseractExecutableURL() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/tesseract",
            "/usr/local/bin/tesseract",
            "/usr/bin/tesseract"
        ]

        return candidates
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    nonisolated private static func installedLanguageCodes() -> Set<String> {
        let tessdataURLs = [
            "/opt/homebrew/share/tessdata",
            "/usr/local/share/tessdata",
            "/usr/share/tessdata"
        ].map(URL.init(fileURLWithPath:))

        return Set(
            tessdataURLs.flatMap { tessdataURL in
                (try? FileManager.default.contentsOfDirectory(
                    at: tessdataURL,
                    includingPropertiesForKeys: nil
                )) ?? []
            }
            .filter { $0.pathExtension == "traineddata" }
            .map { $0.deletingPathExtension().lastPathComponent }
        )
    }
}
