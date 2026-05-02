// PreferencesView.swift
// Preferences for shortcut, menu bar icon, permissions, privacy, and project info.

import SwiftUI
import Combine
import AppKit

struct PreferencesView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var hotkeys: GlobalHotkeyManager
    @EnvironmentObject var permissions: PermissionsManager
    @StateObject private var ocrSupport = OCRSupportManager()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsHeader()

                SettingsPanel("General") {
                    Toggle("Show menu bar icon", isOn: menuBarIconBinding)
                    Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    Text("If you hide the menu bar icon, open Settings by pressing \(settings.snipeShortcut.displayText), then press Command + comma while the snipping overlay is visible.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SettingsPanel("Keyboard Shortcut") {
                    ShortcutRecorderView(shortcut: $settings.snipeShortcut)
                    Button("Register Shortcut Now") {
                        hotkeys.register(shortcut: settings.snipeShortcut)
                    }
                }

                SettingsPanel("Permissions") {
                    PermissionSettingsRow(
                        icon: "display",
                        title: "Screen Recording",
                        detail: "Required to capture the region you select.",
                        isGranted: permissions.hasScreenRecording,
                        actionTitle: "Open Screen Recording Settings",
                        action: permissions.openScreenRecordingSettings
                    )

                    Divider()

                    PermissionSettingsRow(
                        icon: "hand.tap",
                        title: "Accessibility",
                        detail: "Required for global shortcuts and overlay interactions.",
                        isGranted: permissions.hasAccessibility,
                        actionTitle: "Open Accessibility Settings",
                        action: permissions.openAccessibilitySettings
                    )

                    Button("Recheck Permissions") {
                        permissions.refresh()
                    }
                }

                SettingsPanel("Optional OCR Support") {
                    OCRSupportRow(
                        icon: "terminal",
                        title: "Homebrew",
                        detail: "Used to install local OCR tools.",
                        isReady: ocrSupport.status.hasHomebrew
                    )

                    Divider()

                    OCRSupportRow(
                        icon: "text.viewfinder",
                        title: "Tesseract OCR",
                        detail: "Adds offline OCR for scripts Apple Vision does not support.",
                        isReady: ocrSupport.status.hasTesseract
                    )

                    Divider()

                    OCRSupportRow(
                        icon: "character.book.closed",
                        title: "Tamil and Hindi data",
                        detail: "Required for Tamil and Hindi OCR fallback.",
                        isReady: ocrSupport.status.hasTamil && ocrSupport.status.hasHindi
                    )

                    HStack {
                        Button("Copy Install Command") {
                            ocrSupport.openInstaller()
                        }

                        Button("Recheck") {
                            ocrSupport.refresh()
                        }
                    }
                }

                SettingsPanel("Privacy") {
                    Text("TextSnipper works completely offline. Screen captures are processed locally and copied to your clipboard.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SettingsPanel("About") {
                    Text("TextSnipper")
                        .font(.headline)
                    Text("Version \(Bundle.main.releaseVersion) (\(Bundle.main.buildVersion))")
                        .foregroundStyle(.secondary)
                    Text("Developed by Mohamed Rafiq")
                    Text("Copyright © 2026 Mohamed Rafiq. All rights reserved.")
                        .foregroundStyle(.secondary)
                    Link("www.rafiq.tech", destination: URL(string: "https://www.rafiq.tech")!)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 560, idealWidth: 640, minHeight: 620)
        .onAppear {
            permissions.refresh()
            ocrSupport.refresh()
        }
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            permissions.refresh()
        }
    }

    private var menuBarIconBinding: Binding<Bool> {
        Binding(
            get: { settings.showMenuBarIcon },
            set: { newValue in
                guard newValue == false else {
                    settings.showMenuBarIcon = true
                    return
                }

                if confirmMenuBarIconHide() {
                    settings.showMenuBarIcon = false
                }
            }
        )
    }

    private func confirmMenuBarIconHide() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Hide the menu bar icon?"
        alert.informativeText = "To open Settings later, press \(settings.snipeShortcut.displayText), then press Command + comma while the snipping overlay is visible."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Hide Icon")
        alert.addButton(withTitle: "Keep Icon")
        return alert.runModal() == .alertFirstButtonReturn
    }
}

private extension Bundle {
    var releaseVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    var buildVersion: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}

private struct SettingsHeader: View {
    var body: some View {
        HStack(spacing: 14) {
            AppIconMark(size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text("TextSnipper Settings")
                    .font(.title2.bold())
                Text("Fast local OCR and QR capture from your menu bar.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SettingsPanel<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PermissionSettingsRow: View {
    let icon: String
    let title: String
    let detail: String
    let isGranted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 30)
                .foregroundStyle(isGranted ? .green : .secondary)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline)
                    Spacer(minLength: 8)
                    PermissionStatusPill(isGranted: isGranted)
                }

                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(actionTitle, action: action)
            }
        }
    }
}

private struct OCRSupportRow: View {
    let icon: String
    let title: String
    let detail: String
    let isReady: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 30)
                .foregroundStyle(isReady ? .green : .secondary)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline)
                    Spacer(minLength: 8)
                    Label(isReady ? "Installed" : "Missing", systemImage: isReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isReady ? .green : .orange)
                        .lineLimit(1)
                }

                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
