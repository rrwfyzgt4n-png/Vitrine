import SwiftUI

struct FloatingStatusView: View {
    let message: String
    let locate: (() -> Void)?
    let cancel: (() -> Void)?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(message: String, locate: (() -> Void)? = nil, cancel: (() -> Void)? = nil) {
        self.message = message
        self.locate = locate
        self.cancel = cancel
    }

    var body: some View {
        if reduceTransparency {
            statusContent
                .background(.background, in: .capsule)
                .overlay { Capsule().stroke(.separator) }
                .shadow(radius: 4, y: 2)
        } else {
            statusContent
                .glassEffect(.regular, in: .capsule)
                .shadow(radius: 8, y: 3)
        }
    }

    private var statusContent: some View {
        HStack(spacing: 10) {
            if locate == nil { ProgressView().controlSize(.small) }
            Text(message).lineLimit(1)
            if let locate { Button("Locate…", action: locate) }
            if let cancel { Button("Cancel", action: cancel) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}
