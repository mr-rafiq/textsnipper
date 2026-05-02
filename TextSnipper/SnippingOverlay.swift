// TextSnipper — Developed by Mohamed Rafiq (mohamed-rafiq@outlook.com)
// GitHub: mr-rafiq
// © 2026 Mohamed Rafiq. All rights reserved.

// SnippingOverlay.swift
// Fullscreen overlay to select a rectangular region.

import SwiftUI
import AppKit

final class SnippingCoordinator {
    static let shared = SnippingCoordinator()
    private init() {}

    func startSnip() {
        OverlayWindowController.shared.beginSelection { rect in
            guard let image = ScreenCaptureService.capture(rect: rect) else { return }
            OCRPipeline.process(image: image)
        }
    }
}

final class OverlayWindowController: NSWindowController, NSWindowDelegate {
    static let shared = OverlayWindowController()

    private var onComplete: ((CGRect) -> Void)?

    private init() {
        let content = OverlayView()
        let hosting = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hosting)
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = false
        window.styleMask = []
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        super.init(window: window)
        window.delegate = self
        content.onFinish = { [weak self] rect in
            self?.close()
            self?.onComplete?(rect)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func beginSelection(onComplete: @escaping (CGRect) -> Void) {
        self.onComplete = onComplete
        if let screen = NSScreen.main {
            window?.setFrame(screen.frame, display: true)
        }
        show()
    }

    func show() { self.window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
}

struct OverlayView: View {
    @State private var startPoint: CGPoint? = nil
    @State private var currentPoint: CGPoint? = nil
    var onFinish: ((CGRect) -> Void)?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if startPoint == nil { startPoint = value.startLocation }
                            currentPoint = value.location
                        }
                        .onEnded { value in
                            currentPoint = value.location
                            if let rect = selectionRect(in: geo) { onFinish?(rect) }
                            startPoint = nil; currentPoint = nil
                        }
                    )
                if let rect = selectionRect(in: geo) {
                    SelectionRect(rect: rect)
                }
            }
            .onExitCommand { startPoint = nil; currentPoint = nil; onFinish?(.zero) }
        }
    }

    func selectionRect(in geo: GeometryProxy) -> CGRect? {
        guard let s = startPoint, let c = currentPoint else { return nil }
        let x = min(s.x, c.x)
        let y = min(s.y, c.y)
        let w = abs(s.x - c.x)
        let h = abs(s.y - c.y)
        let frame = geo.frame(in: .global)
        return CGRect(x: frame.minX + x, y: frame.minY + (frame.height - (y + h)), width: w, height: h)
    }
}

struct SelectionRect: View {
    let rect: CGRect
    var body: some View {
        Rectangle()
            .stroke(Color.accentColor, lineWidth: 2)
            .background(Rectangle().fill(Color.clear))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: (NSScreen.main?.frame.height ?? 0) - rect.midY)
    }
}

