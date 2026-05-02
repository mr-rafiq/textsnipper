import AppKit
import SwiftUI

@MainActor
final class AppSettingsWindowController: NSWindowController {
    static let shared = AppSettingsWindowController()

    private var settings: SettingsStore?
    private var hotkeys: GlobalHotkeyManager?
    private var permissions: PermissionsManager?
    private var clipboardHistory: ClipboardHistoryStore?

    private init() {
        let window = NSWindow()
        window.title = "TextSnipper Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 560, height: 620)
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(settings: SettingsStore, hotkeys: GlobalHotkeyManager, permissions: PermissionsManager, clipboardHistory: ClipboardHistoryStore) {
        self.settings = settings
        self.hotkeys = hotkeys
        self.permissions = permissions
        self.clipboardHistory = clipboardHistory
    }

    func show() {
        guard let settings, let hotkeys, let permissions, let clipboardHistory else { return }

        let view = PreferencesView()
            .environmentObject(settings)
            .environmentObject(hotkeys)
            .environmentObject(permissions)
            .environmentObject(clipboardHistory)

        window?.contentViewController = NSHostingController(rootView: view)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
