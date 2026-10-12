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
    var cornerRadius: CGFloat = 14
    var padding: CGFloat = 14
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        OCTheme.glass.opacity(0.28),
                                        OCTheme.glassDeep.opacity(0.40),
                                        Color.white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.28), Color.white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: OCTheme.shadow, radius: 12, x: 0, y: 4)
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minWidth: 120, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(OCTheme.glass.opacity(emphasize ? 0.32 : 0.18))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            emphasize ? OCTheme.accent.opacity(0.45) : Color.white.opacity(0.16),
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
