// ScreenCaptureService.swift
// Captures a selected region. Also provides a way to probe Screen Recording permission.

import AppKit
import CoreGraphics

enum ScreenCaptureService {
    static func hasScreenRecordingPermission() -> Bool {
        // Attempt a minimal CGWindowListCreateImage capture of a 1x1 rect; if it returns nil, likely permission missing.
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        let image = CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution])
        return image != nil
    }

    static func capture(rect: CGRect) -> NSImage? {
        guard let cgImage = CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution]) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: .zero)
    }
}
