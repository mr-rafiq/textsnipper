import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TextSnipper")
                .font(.title2.bold())
            Text("Use Shift + Command + 2 to snip any region. Recognized text or QR payload is copied to your clipboard.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 420)
    }
}

#Preview {
    ContentView()
}
