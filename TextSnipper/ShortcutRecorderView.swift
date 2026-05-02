// ShortcutRecorderView.swift
// Simple placeholder shortcut recorder UI.

import SwiftUI

struct ShortcutRecorderView: View {
    @Binding var shortcut: Shortcut

    var body: some View {
        HStack {
            Text("Shortcut:")
            TextField("Key", text: $shortcut.key)
                .frame(width: 40)
            Toggle("⌘", isOn: Binding(get: { shortcut.modifiers.contains(.command) }, set: { $0 ? shortcut.modifiers.insert(.command) : shortcut.modifiers.remove(.command) }))
            Toggle("⇧", isOn: Binding(get: { shortcut.modifiers.contains(.shift) }, set: { $0 ? shortcut.modifiers.insert(.shift) : shortcut.modifiers.remove(.shift) }))
            Toggle("⌥", isOn: Binding(get: { shortcut.modifiers.contains(.option) }, set: { $0 ? shortcut.modifiers.insert(.option) : shortcut.modifiers.remove(.option) }))
            Toggle("⌃", isOn: Binding(get: { shortcut.modifiers.contains(.control) }, set: { $0 ? shortcut.modifiers.insert(.control) : shortcut.modifiers.remove(.control) }))
        }
    }
}

struct EventModifiers: OptionSet, Codable {
    let rawValue: Int
    static let command = EventModifiers(rawValue: 1 << 0)
    static let shift = EventModifiers(rawValue: 1 << 1)
    static let option = EventModifiers(rawValue: 1 << 2)
    static let control = EventModifiers(rawValue: 1 << 3)

    mutating func insert(_ member: EventModifiers) { self = EventModifiers(rawValue: self.rawValue | member.rawValue) }
    mutating func remove(_ member: EventModifiers) { self = EventModifiers(rawValue: self.rawValue & ~member.rawValue) }
    func contains(_ member: EventModifiers) -> Bool { (rawValue & member.rawValue) != 0 }
}
