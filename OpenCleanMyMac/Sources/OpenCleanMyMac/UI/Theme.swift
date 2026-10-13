import AppKit
import SwiftUI

/// Blue glass operate palette — frosted indigo panels.
enum OCTheme {
    static let canvas = Color(red: 0.05, green: 0.10, blue: 0.20)
    static let canvasElevated = Color(red: 0.08, green: 0.16, blue: 0.30)
    static let mist = Color(red: 0.12, green: 0.24, blue: 0.42)

    static let ink = Color(red: 0.96, green: 0.98, blue: 1.0)
    static let muted = Color(red: 0.68, green: 0.78, blue: 0.92)
    static let faint = Color(red: 0.48, green: 0.58, blue: 0.74)

    /// Primary action / links
    static let sea = Color(red: 0.30, green: 0.68, blue: 1.0)
    static let seaDeep = Color(red: 0.16, green: 0.48, blue: 0.92)
    /// Heat / attention
    static let accent = Color(red: 1.0, green: 0.62, blue: 0.28)
    static let danger = Color(red: 0.95, green: 0.42, blue: 0.45)
    static let success = Color(red: 0.32, green: 0.90, blue: 0.55)

    static let glass = Color(red: 0.18, green: 0.42, blue: 0.82)
    static let glassDeep = Color(red: 0.04, green: 0.10, blue: 0.24)
    static let glassGlow = Color(red: 0.28, green: 0.58, blue: 1.0)

    /// Back-compat aliases used across views
    static let violet = glass
    static let violetDeep = glassDeep
    static let violetGlow = glassGlow

    static let card = Color.white.opacity(0.08)
    static let cardHover = Color.white.opacity(0.12)
    static let stroke = Color.white.opacity(0.14)
    static let strokeStrong = Color.white.opacity(0.22)
    static let sidebarFill = Color(red: 0.04, green: 0.08, blue: 0.16).opacity(0.75)

    static let shadow = Color.black.opacity(0.40)

    static let display = Font.system(.largeTitle, design: .default).weight(.bold)
    static let title = Font.system(.title2, design: .default).weight(.semibold)
    static let headline = Font.system(.headline, design: .default)
    static let body = Font.system(.body, design: .default)
    static let caption = Font.system(.caption, design: .default)
    static let mono = Font.system(.body, design: .monospaced).weight(.medium)
}

struct OCGlassMaterial: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blending
        nsView.state = .active
    }
}

struct OCScreenBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.22, blue: 0.42),
                    Color(red: 0.04, green: 0.08, blue: 0.18),
                    Color(red: 0.06, green: 0.14, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            GeometryReader { geo in
                Circle()
                    .fill(OCTheme.glassGlow.opacity(0.30))
                    .frame(width: 520, height: 520)
                    .blur(radius: 80)
                    .offset(x: geo.size.width - 200, y: -160)
                Circle()
                    .fill(OCTheme.sea.opacity(0.14))
                    .frame(width: 380, height: 380)
                    .blur(radius: 70)
                    .offset(x: -120, y: geo.size.height - 180)
            }
        }
        .ignoresSafeArea()
    }
}

struct OCGlassPanel<Content: View>: View {
    var cornerRadius: CGFloat = 16
    var padding: CGFloat = 14
    var elevates: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { OCGlassShape(cornerRadius: cornerRadius, elevates: elevates) }
    }
}

/// Apple-style liquid glass: material + blue wash + specular rim + soft depth.
struct OCGlassShape: View {
    var cornerRadius: CGFloat = 16
    var elevates: Bool = true
    var tintOpacity: Double = 0.22

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.14),
                                OCTheme.glass.opacity(tintOpacity),
                                OCTheme.glassDeep.opacity(0.45),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(alignment: .top) {
                // Specular highlight strip
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.white.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: max(18, cornerRadius * 1.1))
                    .padding(.horizontal, 1)
                    .padding(.top, 1)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.42),
                                Color.white.opacity(0.12),
                                OCTheme.sea.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: elevates ? OCTheme.shadow.opacity(0.55) : .clear,
                radius: elevates ? 18 : 0,
                x: 0,
                y: elevates ? 8 : 0
            )
            .shadow(
                color: elevates ? OCTheme.sea.opacity(0.08) : .clear,
                radius: elevates ? 24 : 0,
                x: 0,
                y: elevates ? 12 : 0
            )
    }
}

/// Indeterminate shimmer bar for scans / loads.
struct OCShimmerBar: View {
    var height: CGFloat = 4
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(OCTheme.glassDeep.opacity(0.55))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    OCTheme.sea.opacity(0),
                                    OCTheme.sea.opacity(0.95),
                                    OCTheme.glassGlow.opacity(0.85),
                                    OCTheme.sea.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * 0.38)
                        .offset(x: phase * geo.size.width)
                }
                .clipShape(Capsule())
        }
        .frame(height: height)
        .onAppear {
            phase = -0.4
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: false)) {
                phase = 1.15
            }
        }
    }
}

/// Circular scan progress with soft glow (0…1). Indeterminate when progress < 0.
struct OCScanRing: View {
    var progress: Double
    var lineWidth: CGFloat = 6
    var size: CGFloat = 56
    @State private var spin = false

    private var clamped: Double { min(1, max(0, progress)) }
    private var indeterminate: Bool { progress < 0 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(OCTheme.glass.opacity(0.22), lineWidth: lineWidth)
            if indeterminate {
                Circle()
                    .trim(from: 0.08, to: 0.42)
                    .stroke(
                        AngularGradient(
                            colors: [OCTheme.sea.opacity(0.15), OCTheme.sea, OCTheme.glassGlow],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .onAppear {
                        withAnimation(.linear(duration: 1.05).repeatForever(autoreverses: false)) {
                            spin = true
                        }
                    }
            } else {
                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(
                        AngularGradient(
                            colors: [OCTheme.seaDeep, OCTheme.sea, OCTheme.glassGlow],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.45), value: clamped)
            }
            Circle()
                .fill(.ultraThinMaterial)
                .padding(lineWidth + 2)
                .overlay {
                    Circle().fill(OCTheme.glass.opacity(0.2))
                }
        }
        .frame(width: size, height: size)
        .shadow(color: OCTheme.sea.opacity(0.35), radius: 10, x: 0, y: 0)
    }
}

/// Soft breathing pulse behind busy UI.
struct OCBusyPulse: View {
    @State private var on = false

    var body: some View {
        Circle()
            .fill(OCTheme.sea.opacity(on ? 0.28 : 0.10))
            .blur(radius: 28)
            .scaleEffect(on ? 1.15 : 0.88)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    on = true
                }
            }
    }
}

struct OCCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        OCGlassPanel(padding: padding, content: content)
    }
}

struct OCPageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(OCTheme.ink)
                .tracking(-0.3)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(OCTheme.muted)
                .frame(maxWidth: 560, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct OCMetricChip: View {
    let title: String
    let value: String
    var emphasize: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(OCTheme.faint)
                .textCase(.uppercase)
                .tracking(0.6)
            Text(value)
                .font(.system(size: 22, weight: .semibold).monospacedDigit())
                .foregroundStyle(emphasize ? OCTheme.accent : OCTheme.ink)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minWidth: 120, alignment: .leading)
        .background {
            OCGlassShape(
                cornerRadius: 14,
                elevates: false,
                tintOpacity: emphasize ? 0.34 : 0.18
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        emphasize ? OCTheme.accent.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            }
        }
    }
}

struct SeaButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: configuration.isPressed
                                ? [OCTheme.seaDeep, OCTheme.seaDeep]
                                : [OCTheme.sea, OCTheme.seaDeep],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: OCTheme.sea.opacity(configuration.isPressed ? 0 : 0.35), radius: 10, x: 0, y: 3)
            )
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(OCTheme.accent.opacity(configuration.isPressed ? 0.85 : 1))
                    .shadow(color: OCTheme.accent.opacity(configuration.isPressed ? 0 : 0.28), radius: 8, x: 0, y: 3)
            )
            .foregroundStyle(Color(red: 0.16, green: 0.08, blue: 0.04))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(OCTheme.strokeStrong, lineWidth: 1)
            )
            .foregroundStyle(OCTheme.ink)
    }
}

struct QuitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(OCTheme.danger.opacity(configuration.isPressed ? 0.28 : 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(OCTheme.danger.opacity(0.45), lineWidth: 1)
            )
            .foregroundStyle(OCTheme.ink)
    }
}
