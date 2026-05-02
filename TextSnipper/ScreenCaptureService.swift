// ScreenCaptureService.swift
// Captures a selected region. Also provides a way to probe Screen Recording permission.

import AppKit
import CoreGraphics
import ScreenCaptureKit

enum ScreenCaptureService {
    static func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func capture(rect: CGRect) async -> NSImage? {
        guard hasScreenRecordingPermission() else { return nil }
        guard rect.width >= 4, rect.height >= 4 else { return nil }

        let capturedImage = try? await SCScreenshotManager.captureImage(in: rect)
        guard !Task.isCancelled else { return nil }
        guard let capturedImage else { return nil }
        return NSImage(cgImage: capturedImage, size: .zero)
    }
}
