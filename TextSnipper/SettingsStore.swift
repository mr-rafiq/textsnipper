// SettingsStore.swift
// Stores user preferences in UserDefaults.

import Foundation
import SwiftUI
import Combine

struct Shortcut: Codable, Equatable {
    var key: String // e.g., "2"
    var modifiers: EventModifiers = [.command, .shift]

    var displayText: String {
        var parts = [String]()
        if modifiers.contains(.control) { parts.append("Control") }
        if modifiers.contains(.option) { parts.append("Option") }
        if modifiers.contains(.shift) { parts.append("Shift") }
        if modifiers.contains(.command) { parts.append("Command") }
        parts.append(key.uppercased())
        return parts.joined(separator: " + ")
    }
}

final class SettingsStore: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    @AppStorage("showMenuBarIcon") var showMenuBarIcon: Bool = true
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("enableAdditionalOCRSupport") var enableAdditionalOCRSupport: Bool = false
    @AppStorage("enableClipboardHistory") var enableClipboardHistory: Bool = true
    @AppStorage("snipeShortcut") private var snipeShortcutData: Data = (try! JSONEncoder().encode(Shortcut(key: "2")))

    var snipeShortcut: Shortcut {
        get { (try? JSONDecoder().decode(Shortcut.self, from: snipeShortcutData)) ?? Shortcut(key: "2") }
        set { snipeShortcutData = (try! JSONEncoder().encode(newValue)); objectWillChange.send() }
    }
}
