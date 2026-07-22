import AppKit
import SwiftUI

struct BreathingAppIconView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let lampPositions: [UnitPoint] = [
        .init(x: 0.325, y: 0.24),
        .init(x: 0.505, y: 0.24),
        .init(x: 0.695, y: 0.24),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { context in
            iconWithGlow(intensity: intensity(at: context.date))
        }
        .frame(width: 256, height: 256)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vitrine app icon")
    }

    private func iconWithGlow(intensity: Double) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack(alignment: .topLeading) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)

                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.orange.opacity(0.18 * intensity),
                                Color.yellow.opacity(0.08 * intensity),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size.width * 0.38
                        )
                    )
                    .frame(width: size.width * 0.78, height: size.height * 0.42)
                    .position(x: size.width * 0.51, y: size.height * 0.34)
                    .blendMode(.screen)

                ForEach(Array(lampPositions.enumerated()), id: \.offset) { _, position in
                    Circle()
                        .fill(
                            RadialGradient(
                                stops: [
                                    .init(color: .white.opacity(0.82 * intensity), location: 0),
                                    .init(color: .yellow.opacity(0.50 * intensity), location: 0.18),
                                    .init(color: .orange.opacity(0.24 * intensity), location: 0.48),
                                    .init(color: .clear, location: 1),
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: size.width * 0.11
                            )
                        )
                        .frame(width: size.width * 0.22, height: size.width * 0.22)
                        .scaleEffect(0.90 + 0.10 * intensity)
                        .position(x: size.width * position.x, y: size.height * position.y)
                        .blendMode(.screen)
                }
            }
            .compositingGroup()
        }
    }

    private var icon: NSImage {
        NSApplication.shared.applicationIconImage
            ?? NSImage(systemSymbolName: "books.vertical", accessibilityDescription: nil)
            ?? NSImage()
    }

    private func intensity(at date: Date) -> Double {
        if reduceMotion { return reduceTransparency ? 0.22 : 0.36 }
        let phase = date.timeIntervalSinceReferenceDate * (2 * .pi / 5.5)
        let breathingValue = 0.5 + 0.5 * sin(phase)
        let minimum = reduceTransparency ? 0.18 : 0.28
        let range = reduceTransparency ? 0.18 : 0.42
        return minimum + range * breathingValue
    }
}
