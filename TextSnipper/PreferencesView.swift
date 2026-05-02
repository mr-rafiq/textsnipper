// PreferencesView.swift
// Minimal preferences for shortcut, menu bar icon, launch at login.

import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var hotkeys: GlobalHotkeyManager
    @EnvironmentObject var permissions: PermissionsManager

    var body: some View {
        Form {
            Section("General") {
                Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
            }
            Section("Keyboard Shortcut") {
                ShortcutRecorderView(shortcut: $settings.snipeShortcut)
                Button("Register Shortcut Now") { hotkeys.register(shortcut: settings.snipeShortcut) }
            }
            Section("Permissions") {
                Button("Open Screen Recording Settings") { permissions.openScreenRecordingSettings() }
                Button("Open Accessibility Settings") { permissions.openAccessibilitySettings() }
            }
            Section("Privacy") {
                Text("TextSnipper works completely offline. No analytics or network requests.")
            }
        }
        .padding()
    }
}
