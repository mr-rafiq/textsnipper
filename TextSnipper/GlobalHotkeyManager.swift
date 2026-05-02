// TextSnipper — Developed by Mohamed Rafiq (mohamed-rafiq@outlook.com)
// GitHub: mr-rafiq
// © 2026 Mohamed Rafiq. All rights reserved.

import AppKit
import Combine
import Carbon.HIToolbox

final class GlobalHotkeyManager: ObservableObject {
    private var hotKeyRef: EventHotKeyRef? = nil
    private var eventHandler: EventHandlerRef? = nil

    init() {
        installHandler()
    }

    deinit {
        unregister()
        removeHandler()
    }

    func register(shortcut: Shortcut) {
        unregister()

        let keyCode = keyCodeForShortcut(shortcut)
        let modifiers = carbonModifiers(from: shortcut.modifiers)

        let hotKeyID = EventHotKeyID(signature: OSType(fourCharCode: "TSNP"), id: 1)
        let status = RegisterEventHotKey(UInt32(keyCode), modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("RegisterEventHotKey failed: \(status)")
        }
    }

    func unregister() {
        if let hk = hotKeyRef { UnregisterEventHotKey(hk); hotKeyRef = nil }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { (next, event, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            if status == noErr && hotKeyID.signature == OSType(fourCharCode: "TSNP") {
                DispatchQueue.main.async {
                    SnippingCoordinator.shared.startSnip()
                }
                return noErr
            }
            return CallNextEventHandler(next, event)
        }
        InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &eventType, nil, &eventHandler)
    }

    private func removeHandler() {
        if let handler = eventHandler { RemoveEventHandler(handler); eventHandler = nil }
    }

    private func keyCodeForShortcut(_ shortcut: Shortcut) -> Int {
        // Map alphanumeric key to virtual keycode. For digits, use kVK_ANSI_0..9.
        if let scalar = shortcut.key.unicodeScalars.first {
            switch scalar {
            case "0": return kVK_ANSI_0
            case "1": return kVK_ANSI_1
            case "2": return kVK_ANSI_2
            case "3": return kVK_ANSI_3
            case "4": return kVK_ANSI_4
            case "5": return kVK_ANSI_5
            case "6": return kVK_ANSI_6
            case "7": return kVK_ANSI_7
            case "8": return kVK_ANSI_8
            case "9": return kVK_ANSI_9
            default:
                // Basic letters A-Z mapping
                let s = String(scalar).lowercased()
                if s == "a" { return kVK_ANSI_A }
                if s == "b" { return kVK_ANSI_B }
                if s == "c" { return kVK_ANSI_C }
                if s == "d" { return kVK_ANSI_D }
                if s == "e" { return kVK_ANSI_E }
                if s == "f" { return kVK_ANSI_F }
                if s == "g" { return kVK_ANSI_G }
                if s == "h" { return kVK_ANSI_H }
                if s == "i" { return kVK_ANSI_I }
                if s == "j" { return kVK_ANSI_J }
                if s == "k" { return kVK_ANSI_K }
                if s == "l" { return kVK_ANSI_L }
                if s == "m" { return kVK_ANSI_M }
                if s == "n" { return kVK_ANSI_N }
                if s == "o" { return kVK_ANSI_O }
                if s == "p" { return kVK_ANSI_P }
                if s == "q" { return kVK_ANSI_Q }
                if s == "r" { return kVK_ANSI_R }
                if s == "s" { return kVK_ANSI_S }
                if s == "t" { return kVK_ANSI_T }
                if s == "u" { return kVK_ANSI_U }
                if s == "v" { return kVK_ANSI_V }
                if s == "w" { return kVK_ANSI_W }
                if s == "x" { return kVK_ANSI_X }
                if s == "y" { return kVK_ANSI_Y }
                if s == "z" { return kVK_ANSI_Z }
            }
        }
        return kVK_ANSI_2 // default to '2'
    }

    private func carbonModifiers(from mods: EventModifiers) -> UInt32 {
        var result: UInt32 = 0
        if mods.contains(.command) { result |= UInt32(cmdKey) }
        if mods.contains(.shift) { result |= UInt32(shiftKey) }
        if mods.contains(.option) { result |= UInt32(optionKey) }
        if mods.contains(.control) { result |= UInt32(controlKey) }
        return result
    }
}

private extension OSType {
    init(fourCharCode: String) {
        precondition(fourCharCode.utf16.count == 4, "fourCharCode must be 4 chars")
        var result: UInt32 = 0
        for scalar in fourCharCode.utf16 { result = (result << 8) + UInt32(scalar) }
        self.init(result)
    }
}
