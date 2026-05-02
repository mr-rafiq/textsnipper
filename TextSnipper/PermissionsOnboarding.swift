// PermissionsOnboarding.swift
// SwiftUI onboarding UI to guide enabling permissions and explain offline/privacy.

import SwiftUI
import AppKit
import Combine

struct PermissionsOnboardingView: View {
    @ObservedObject var permissions: PermissionsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                AppIconMark(size: 64)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome to TextSnipper")
                        .font(.largeTitle.bold())
                        .lineLimit(2)
                    Text("Enable permissions once, then control TextSnipper from the menu bar.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                PermissionRow(
                    icon: "display",
                    title: "Screen Recording",
                    detail: "Required to capture the selected screen area for OCR and QR detection.",
                    isGranted: permissions.hasScreenRecording
                ) {
                    permissions.openScreenRecordingSettings()
                }

                PermissionRow(
                    icon: "hand.tap",
                    title: "Accessibility",
                    detail: "Required for the global shortcut and snipping overlay interactions.",
                    isGranted: permissions.hasAccessibility
                ) {
                    permissions.openAccessibilitySettings()
                }
            }

            HStack {
                Button("Recheck") { permissions.refresh() }
                Spacer()
                Button("Continue") {
                    permissions.completeFirstRunSetup()
                    PermissionsOnboardingWindowController.shared.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(minWidth: 620, idealWidth: 680)
        .onAppear { permissions.refresh() }
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            permissions.refresh()
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let detail: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .frame(width: 36)
                .foregroundStyle(isGranted ? .green : .secondary)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline)
                    Spacer(minLength: 8)
                    PermissionStatusPill(isGranted: isGranted)
                }

                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if isGranted {
                    Text("Ready")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                } else {
                    Button("Open System Settings", action: action)
                }
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

final class PermissionsOnboardingWindowController: NSWindowController {
    static let shared = PermissionsOnboardingWindowController()

    private let fallbackPermissions = PermissionsManager()

    private init() {
        let hosting = NSHostingController(rootView: PermissionsOnboardingView(permissions: fallbackPermissions))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Enable Permissions"
        window.styleMask = [.titled, .closable]
        window.minSize = NSSize(width: 620, height: 460)
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(using permissions: PermissionsManager) {
        permissions.refresh()
        if let hosting = window?.contentViewController as? NSHostingController<PermissionsOnboardingView> {
            hosting.rootView = PermissionsOnboardingView(permissions: permissions)
        }
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    override func close() {
        self.window?.close()
    }
}
