// PermissionsManager.swift
// Handles Screen Recording and Accessibility permission checks and guides users to System Settings.

import Foundation
import AppKit
import Combine

final class PermissionsManager: ObservableObject {
    @Published private(set) var hasScreenRecording = false
    @Published private(set) var hasAccessibility = false
    @Published var onboardingNeeded = true

    private var cancellables = Set<AnyCancellable>()

    init() {
        refresh()
    }

    func refresh() {
        hasScreenRecording = ScreenRecordingPermission.isGranted
        hasAccessibility = AXIsProcessTrustedWithOptions(nil)
        onboardingNeeded = !(hasScreenRecording && hasAccessibility)
    }

    func presentOnboarding() {
        // Open our onboarding window (SwiftUI sheet) if present, otherwise open System Settings links.
        PermissionsOnboardingWindowController.shared.show()
    }

    func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}

enum ScreenRecordingPermission {
    static var isGranted: Bool {
        // There is no direct public API to query; attempt a tiny capture and infer.
        // For scaffold purposes, return stored flag; real implementation will probe capture result.
        return ScreenCaptureService.hasScreenRecordingPermission()
    }
}
