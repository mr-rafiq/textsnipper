// SettingsStore.swift
// Stores user preferences in UserDefaults.

import Foundation
import SwiftUI

struct Shortcut: Codable, Equatable {
    var key: String // e.g., "2"
    var modifiers: EventModifiers = [.command, .shift]
}

final class SettingsStore: ObservableObject {
    @AppStorage("showMenuBarIcon") var showMenuBarIcon: Bool = true
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("snipeShortcut") private var snipeShortcutData: Data = (try! JSONEncoder().encode(Shortcut(key: "2")))

    var snipeShortcut: Shortcut {
        get { (try? JSONDecoder().decode(Shortcut.self, from: snipeShortcutData)) ?? Shortcut(key: "2") }
        set { snipeShortcutData = (try! JSONEncoder().encode(newValue)); objectWillChange.send() }
    }
}
