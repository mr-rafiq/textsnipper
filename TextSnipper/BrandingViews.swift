import AppKit
import SwiftUI

struct AppIconMark: View {
    let size: CGFloat

    var body: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: max(6, size * 0.18), style: .continuous))
            .accessibilityLabel("TextSnipper app icon")
    }
}

struct PermissionStatusPill: View {
    let isGranted: Bool

    var body: some View {
        Label(isGranted ? "Enabled" : "Needs access", systemImage: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(isGranted ? .green : .orange)
            .lineLimit(1)
    }
}
