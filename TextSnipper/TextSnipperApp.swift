import SwiftUI
import AppKit
import Combine

@main
struct TextSnipperApp: App {
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @StateObject private var appController = AppController()

    var body: some Scene {
        MenuBarExtra("TextSnipper", systemImage: "text.viewfinder", isInserted: $showMenuBarIcon) {
            MenuBarContentView()
                .environmentObject(appController.settings)
                .environmentObject(appController.hotkeys)
                .environmentObject(appController.permissions)
                .environmentObject(appController.clipboardHistory)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            PreferencesView()
                .environmentObject(appController.settings)
                .environmentObject(appController.hotkeys)
                .environmentObject(appController.permissions)
                .environmentObject(appController.clipboardHistory)
                .frame(minWidth: 560, idealWidth: 640, minHeight: 620)
        }
    }
}

private struct MenuBarContentView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var hotkeys: GlobalHotkeyManager
    @EnvironmentObject var permissions: PermissionsManager
    @EnvironmentObject var clipboardHistory: ClipboardHistoryStore

    var body: some View {
        Button("Snip Now") {
            SnippingCoordinator.shared.startSnip()
        }
        .keyboardShortcut("2", modifiers: [.command, .shift])

        Button("Clipboard History") {
            ClipboardHistoryWindowController.shared.showAtCursor()
        }
        .disabled(!settings.enableClipboardHistory)

        Button("Recheck Permissions") {
            permissions.refresh()
            if permissions.onboardingNeeded {
                permissions.presentOnboarding()
            }
        }

        Button("Settings") {
            AppSettingsWindowController.shared.show()
        }

        Divider()

        Button("Quit TextSnipper") {
            NSApplication.shared.terminate(nil)
        }
    }
}

@MainActor
final class AppController: ObservableObject {
    let settings = SettingsStore()
    let hotkeys = GlobalHotkeyManager()
    let permissions = PermissionsManager()
    let clipboardHistory = ClipboardHistoryStore()

    private var cancellables = Set<AnyCancellable>()

    init() {
        NSApp.setActivationPolicy(.accessory)

        SnippingCoordinator.shared.configure(settings: settings, clipboardHistory: clipboardHistory)
        ClipboardHistoryWindowController.shared.configure(store: clipboardHistory)
        registerHotkeys()
        AppSettingsWindowController.shared.configure(
            settings: settings,
            hotkeys: hotkeys,
            permissions: permissions,
            clipboardHistory: clipboardHistory
        )

        settings.objectWillChange
            .sink { [weak self] in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.registerHotkeys()
                }
            }
            .store(in: &cancellables)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.permissions.refresh()
            if self.permissions.onboardingNeeded && !PermissionsManager.hasCompletedFirstRunSetup {
                self.permissions.presentOnboarding()
            } else if !self.permissions.onboardingNeeded {
                self.permissions.completeFirstRunSetup()
            }
        }
    }

    private func registerHotkeys() {
        hotkeys.registerSnipShortcut(settings.snipeShortcut) {
            SnippingCoordinator.shared.startSnip()
        }
        hotkeys.registerClipboardHistory(enabled: settings.enableClipboardHistory) {
            ClipboardHistoryWindowController.shared.showAtCursor()
        }
    }
}
