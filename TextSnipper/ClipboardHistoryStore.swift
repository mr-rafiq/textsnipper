// ClipboardHistoryStore.swift
// Stores local TextSnipper clipboard history and presents quick paste UI.

import AppKit
import Combine
import Carbon.HIToolbox
import SwiftUI

struct ClipboardHistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date

    init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}

@MainActor
final class ClipboardHistoryStore: ObservableObject {
    @Published private(set) var entries = [ClipboardHistoryEntry]()

    private let defaultsKey = "clipboardHistoryEntries"
    private let maximumEntries = 50

    init() {
        load()
    }

    func add(_ text: String) {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else { return }

        entries.removeAll { $0.text == cleanedText }
        entries.insert(ClipboardHistoryEntry(text: cleanedText), at: 0)
        if entries.count > maximumEntries {
            entries.removeLast(entries.count - maximumEntries)
        }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([ClipboardHistoryEntry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

@MainActor
final class ClipboardHistoryWindowController: NSWindowController, NSWindowDelegate {
    static let shared = ClipboardHistoryWindowController()

    private var store: ClipboardHistoryStore?
    private var targetApplication: NSRunningApplication?

    private init() {
        let panel = ClipboardHistoryPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        super.init(window: panel)
        panel.delegate = self
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(store: ClipboardHistoryStore) {
        self.store = store
        window?.contentViewController = NSHostingController(
            rootView: ClipboardHistoryPopupView(
                store: store,
                onPaste: { [weak self] text in self?.paste(text) },
                onClose: { [weak self] in self?.close() }
            )
        )
    }

    func showAtCursor() {
        guard store != nil else { return }

        let currentApp = NSRunningApplication.current
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        targetApplication = frontmostApp?.bundleIdentifier == currentApp.bundleIdentifier ? targetApplication : frontmostApp

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            self?.presentAtCursor()
        }
    }

    private func presentAtCursor() {
        guard let window, store != nil else { return }
        let cursor = NSEvent.mouseLocation
        let visibleFrame = NSScreen.screens
            .first { $0.frame.contains(cursor) }?
            .visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let size = window.frame.size
        let origin = NSPoint(
            x: min(max(cursor.x - 18, visibleFrame.minX + 8), visibleFrame.maxX - size.width - 8),
            y: min(max(cursor.y - size.height + 18, visibleFrame.minY + 8), visibleFrame.maxY - size.height - 8)
        )

        window.setFrameOrigin(origin)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func paste(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        close()

        targetApplication?.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            Self.sendPasteShortcut()
        }
    }

    private static func sendPasteShortcut() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

private final class ClipboardHistoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private struct ClipboardHistoryPopupView: View {
    @ObservedObject var store: ClipboardHistoryStore
    let onPaste: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Clipboard")
                    .font(.headline)
                Spacer()
                Button(action: store.clear) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Clear history")

                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Close")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            if store.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No copied snips yet")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(28)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.entries) { entry in
                            Button {
                                onPaste(entry.text)
                            } label: {
                                ClipboardHistoryRow(entry: entry)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .padding(.leading, 14)
                        }
                    }
                }
            }
        }
        .frame(width: 360, height: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
    }
}

private struct ClipboardHistoryRow: View {
    let entry: ClipboardHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(entry.text)
                .font(.callout)
                .lineLimit(3)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            Text(entry.createdAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
