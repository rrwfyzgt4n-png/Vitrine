import SwiftUI

struct BreathingAppIconView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsBrightFrame = false

    var body: some View {
        ZStack {
            icon(named: "AboutBookcaseDimmed")
            icon(named: "AboutBookcaseBright")
                .opacity(showsBrightFrame ? 1 : 0)
        }
        .frame(width: 230, height: 230)
        .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vitrine app icon")
        .task(id: reduceMotion) {
            if reduceMotion {
                showsBrightFrame = true
                return
            }

            showsBrightFrame = false
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                withAnimation(.smooth(duration: 2.4)) {
                    showsBrightFrame.toggle()
                }
            }
        }
    }

    private func icon(named name: String) -> some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
    }
}
