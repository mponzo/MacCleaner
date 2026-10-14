import SwiftUI

/// Prominent in-progress banner with determinate/indeterminate bar and optional Stop.
struct OCOperationBanner: View {
    let title: String
    var detail: String? = nil
    /// `nil` = indeterminate shimmer; `0...1` = determinate bar.
    var progress: Double? = nil
    var onStop: (() -> Void)? = nil
    var stopTitle: String = L10n.string("smartcare.stop")

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(OCTheme.font(13, weight: .semibold))
                        .foregroundStyle(OCTheme.ink)
                        .lineLimit(2)
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(OCTheme.font(11))
                            .foregroundStyle(OCTheme.muted)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if let onStop {
                    Button(stopTitle, action: onStop)
                        .buttonStyle(GhostButtonStyle())
                        .keyboardShortcut(.cancelAction)
                }
            }

            if let progress {
                ProgressView(value: min(max(progress, 0), 1))
                    .tint(OCTheme.sea)
            } else {
                OCShimmerBar(height: 5)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(OCTheme.canvasElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(OCTheme.sea.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
