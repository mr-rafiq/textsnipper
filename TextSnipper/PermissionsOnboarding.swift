// PermissionsOnboarding.swift
// SwiftUI onboarding UI to guide enabling permissions and explain offline/privacy.

import SwiftUI
import AppKit

struct PermissionsOnboardingView: View {
    @EnvironmentObject var permissions: PermissionsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to TextSnipper")
                .font(.largeTitle).bold()
            Text("TextSnipper runs entirely offline. To snip the screen and recognize text/QR codes, please enable the following permissions.")
                .foregroundStyle(.secondary)

            PermissionRow(icon: "display", title: "Screen Recording", detail: "Required to capture the selected screen area for OCR/QR.") {
                permissions.openScreenRecordingSettings()
            }
            PermissionRow(icon: "hand.tap", title: "Accessibility", detail: "Needed for global shortcuts and overlay interactions.") {
                permissions.openAccessibilitySettings()
            }

            HStack {
                Button("Recheck") { permissions.refresh() }
                Spacer()
                Button("Done") { PermissionsOnboardingWindowController.shared.close() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(permissions.onboardingNeeded)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary)
                Button("Open System Settings…", action: action)
            }
        }
    }
}

final class PermissionsOnboardingWindowController: NSWindowController {
    static let shared = PermissionsOnboardingWindowController()

    private init() {
        let hosting = NSHostingController(rootView: PermissionsOnboardingView().environmentObject(PermissionsManager()))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Enable Permissions"
        window.styleMask = [.titled, .closable]
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() { self.window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    func close() { self.window?.close() }
}
