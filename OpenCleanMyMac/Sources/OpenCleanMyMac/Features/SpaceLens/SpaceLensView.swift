import SwiftUI

struct SpaceLensView: View {
    @Bindable var engine: ScanEngine

    private var slices: [(ScanCategory, Int64)] {
        engine.results
            .filter { $0.totalBytes > 0 }
            .map { ($0.category, $0.totalBytes) }
            .sorted { $0.1 > $1.1 }
    }

    private var maxBytes: Int64 {
        slices.first?.1 ?? 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                OCPageHeader(
                    title: L10n.string("space.title"),
                    subtitle: L10n.string("space.subtitle")
                )

                if slices.isEmpty {
                    ContentUnavailableView(
                        L10n.string("space.empty"),
                        systemImage: "chart.bar",
                        description: Text(l10n: "space.empty.detail")
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(slices.enumerated()), id: \.element.0) { index, slice in
                            barRow(category: slice.0, bytes: slice.1, rank: index)
                        }
                    }
                    .padding(18)
                    .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(OCTheme.stroke)
                    )
                }
            }
            .padding(28)
        }
    }

    private func barRow(category: ScanCategory, bytes: Int64, rank: Int) -> some View {
        let ratio = max(0.04, CGFloat(bytes) / CGFloat(maxBytes))
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: category.systemImage)
                    .foregroundStyle(OCTheme.sea)
                Text(category.title)
                    .font(.headline)
                Spacer()
                Text(ByteFormat.string(bytes))
                    .font(.body.monospacedDigit().weight(.semibold))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: rank < 2
                                    ? [OCTheme.accent, OCTheme.sea]
                                    : [OCTheme.sea, OCTheme.seaDeep],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * ratio)
                }
            }
            .frame(height: 12)
        }
    }
}
