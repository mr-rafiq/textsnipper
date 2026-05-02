// TextSnipper — Developed by Mohamed Rafiq (mohamed-rafiq@outlook.com)
// GitHub: mr-rafiq
// © 2026 Mohamed Rafiq. All rights reserved.

// SnippingOverlay.swift
// Fullscreen overlay to select a rectangular region.

import SwiftUI
import AppKit

@MainActor
final class SnippingCoordinator {
    static let shared = SnippingCoordinator()

    private var activeTask: Task<Void, Never>?
    private var escapeMonitor: Any?

    private init() {}

    func startSnip() {
        cancelActiveSnip()

        OverlayWindowController.shared.beginSelection { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let rect):
                self.processSelection(rect)
            case .cancelled:
                self.cancelActiveSnip()
            }
        }
    }

    func cancelActiveSnip() {
        OverlayWindowController.shared.cancelSelection()
        activeTask?.cancel()
        activeTask = nil
        removeEscapeMonitor()
    }

    private func processSelection(_ rect: CGRect) {
        guard rect.width >= 4, rect.height >= 4 else { return }

        installEscapeMonitor()

        activeTask = Task { [weak self] in
            defer {
                Task { @MainActor in
                    self?.activeTask = nil
                    self?.removeEscapeMonitor()
                }
            }

            guard let image = await ScreenCaptureService.capture(rect: rect), !Task.isCancelled else { return }
            guard let output = await OCRPipeline.recognize(image: image), !Task.isCancelled else { return }

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(output, forType: .string)
        }
    }

    private func installEscapeMonitor() {
        removeEscapeMonitor()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            Task { @MainActor in self?.cancelActiveSnip() }
            return nil
        }
    }

    private func removeEscapeMonitor() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
    }
}

enum SnippingResult {
    case success(CGRect)
    case cancelled

    func mapRect(_ transform: (CGRect) -> CGRect) -> SnippingResult {
        switch self {
        case .success(let rect):
            return .success(transform(rect))
        case .cancelled:
            return .cancelled
        }
    }
}

@MainActor
final class OverlayWindowController: NSWindowController, NSWindowDelegate {
    static let shared = OverlayWindowController()

    private var onComplete: ((SnippingResult) -> Void)?
    private var escapeMonitor: Any?
    private var globalKeyMonitor: Any?
    private var cursorMonitor: Any?
    private var cursorPushed = false

    private init() {
        let hosting = NSHostingController(rootView: OverlayView())
        let window = SnippingOverlayWindow(contentViewController: hosting)
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.styleMask = []
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        super.init(window: window)
        window.delegate = self

        hosting.rootView.onFinish = { [weak self] result in
            self?.finish(result)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func beginSelection(onComplete: @escaping (SnippingResult) -> Void) {
        self.onComplete = onComplete
        if let screen = NSScreen.main {
            window?.setFrame(screen.frame, display: true)
        }
        show()
    }

    func cancelSelection() {
        guard window?.isVisible == true else { return }
        finish(.cancelled)
    }

    func show() {
        installEscapeMonitor()
        installCursorMonitor()
        pushSnippingCursor()
        self.window?.makeKeyAndOrderFront(nil)
        self.window?.makeFirstResponder(self.window?.contentView)
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.screenshotSelection.set()
    }

    override func close() {
        removeEscapeMonitor()
        removeCursorMonitor()
        popSnippingCursor()
        super.close()
    }

    private func finish(_ result: SnippingResult) {
        let completion = onComplete
        onComplete = nil
        close()
        completion?(result.mapRect { convertSelectionToScreenRect($0) })
    }

    private func convertSelectionToScreenRect(_ rect: CGRect) -> CGRect {
        guard let window else { return rect.integral }
        let windowFrame = window.frame
        return CGRect(
            x: windowFrame.minX + rect.minX,
            y: windowFrame.minY + rect.minY,
            width: rect.width,
            height: rect.height
        ).integral
    }

    private func installEscapeMonitor() {
        removeEscapeMonitor()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if Self.isSettingsShortcut(event) {
                self?.openSettingsFromOverlay()
                return nil
            }

            guard event.keyCode == 53 else { return event }
            Task { @MainActor in self?.finish(.cancelled) }
            return nil
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard Self.isSettingsShortcut(event) else { return }
            Task { @MainActor in self?.openSettingsFromOverlay() }
        }
    }

    private func openSettingsFromOverlay() {
        finish(.cancelled)
        DispatchQueue.main.async {
            AppSettingsWindowController.shared.show()
        }
    }

    private static func isSettingsShortcut(_ event: NSEvent) -> Bool {
        event.keyCode == 43 && event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command)
    }

    private func removeEscapeMonitor() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
    }

    private func installCursorMonitor() {
        removeCursorMonitor()
        cursorMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseDown]) { event in
            NSCursor.screenshotSelection.set()
            return event
        }
    }

    private func removeCursorMonitor() {
        if let cursorMonitor {
            NSEvent.removeMonitor(cursorMonitor)
            self.cursorMonitor = nil
        }
    }

    private func pushSnippingCursor() {
        guard !cursorPushed else { return }
        NSCursor.screenshotSelection.push()
        cursorPushed = true
    }

    private func popSnippingCursor() {
        guard cursorPushed else { return }
        NSCursor.pop()
        cursorPushed = false
    }
}

private final class SnippingOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        if let contentView {
            contentView.addCursorRect(contentView.bounds, cursor: NSCursor.screenshotSelection)
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.screenshotSelection.set()
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.screenshotSelection.set()
        super.mouseMoved(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        NSCursor.screenshotSelection.set()
        super.mouseDragged(with: event)
    }
}

private extension NSCursor {
    static let screenshotSelection: NSCursor = {
        let size = NSSize(width: 38, height: 38)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let image = NSImage(size: size)

        image.lockFocus()

        NSColor.black.withAlphaComponent(0.18).setFill()
        NSBezierPath(ovalIn: CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14)).fill()

        NSColor.white.withAlphaComponent(0.78).setStroke()
        let halo = NSBezierPath(ovalIn: CGRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16))
        halo.lineWidth = 1.25
        halo.stroke()

        func strokeLine(color: NSColor, width: CGFloat, offset: CGFloat = 0) {
            color.setStroke()
            let path = NSBezierPath()
            path.lineWidth = width
            path.lineCapStyle = .square
            path.move(to: CGPoint(x: center.x + offset, y: 3))
            path.line(to: CGPoint(x: center.x + offset, y: size.height - 3))
            path.move(to: CGPoint(x: 3, y: center.y + offset))
            path.line(to: CGPoint(x: size.width - 3, y: center.y + offset))
            path.stroke()
        }

        strokeLine(color: .white.withAlphaComponent(0.9), width: 3)
        strokeLine(color: .black.withAlphaComponent(0.88), width: 1.35)

        image.unlockFocus()

        return NSCursor(image: image, hotSpot: center)
    }()
}

struct OverlayView: View {
    @State private var startPoint: CGPoint? = nil
    @State private var currentPoint: CGPoint? = nil
    var onFinish: ((SnippingResult) -> Void)?

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
                            if let rect = selectionRect(in: geo) { onFinish?(.success(rect)) }
                            startPoint = nil; currentPoint = nil
                        }
                    )
                if let rect = selectionRect(in: geo) {
                    SelectionRect(rect: rect)
                }
            }
            .onExitCommand { cancelSelection() }
        }
    }

    private func cancelSelection() {
        startPoint = nil
        currentPoint = nil
        onFinish?(.cancelled)
    }

    func selectionRect(in geo: GeometryProxy) -> CGRect? {
        guard let s = startPoint, let c = currentPoint else { return nil }
        let x = min(s.x, c.x)
        let y = min(s.y, c.y)
        let w = abs(s.x - c.x)
        let h = abs(s.y - c.y)
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

struct SelectionRect: View {
    let rect: CGRect
    var body: some View {
        Rectangle()
            .stroke(Color.accentColor, lineWidth: 2)
            .background(Rectangle().fill(Color.clear))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}
