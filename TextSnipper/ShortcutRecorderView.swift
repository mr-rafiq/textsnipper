// ShortcutRecorderView.swift
// Lightweight shortcut editor for the menu bar snip command.

import SwiftUI

struct ShortcutRecorderView: View {
    @Binding var shortcut: Shortcut

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shortcut")
                .font(.headline)

            HStack(spacing: 8) {
                TextField("Key", text: $shortcut.key)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)

                ModifierButton(symbol: "command", title: "Command", modifier: .command, shortcut: $shortcut)
                ModifierButton(symbol: "shift", title: "Shift", modifier: .shift, shortcut: $shortcut)
                ModifierButton(symbol: "option", title: "Option", modifier: .option, shortcut: $shortcut)
                ModifierButton(symbol: "control", title: "Control", modifier: .control, shortcut: $shortcut)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ModifierButton: View {
    let symbol: String
    let title: String
    let modifier: EventModifiers
    @Binding var shortcut: Shortcut

    private var isSelected: Bool {
        shortcut.modifiers.contains(modifier)
    }

    var body: some View {
        Button {
            if isSelected {
                shortcut.modifiers.remove(modifier)
            } else {
                shortcut.modifiers.insert(modifier)
            }
        } label: {
            Image(systemName: symbol)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? .accentColor : .secondary)
        .help(title)
        .accessibilityLabel(title)
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
