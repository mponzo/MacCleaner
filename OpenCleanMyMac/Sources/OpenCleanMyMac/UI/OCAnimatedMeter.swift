import SwiftUI

/// Animated proportional bar for real metrics (CPU, memory, category share).
struct OCAnimatedMeter: View {
    var progress: Double
    var height: CGFloat = 6
    var tint: Color = OCTheme.sea
    var track: Color = OCTheme.ink.opacity(0.06)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayed: Double = 0

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(tint)
                    .frame(width: max(clamped > 0 ? 3 : 0, geometry.size.width * displayed))
            }
        }
        .frame(height: height)
        .onAppear { animate(to: clamped) }
        .onChange(of: clamped) { _, newValue in animate(to: newValue) }
    }

    private func animate(to value: Double) {
        if reduceMotion {
            displayed = value
            return
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            displayed = value
        }
    }
}
