import AppKit
import SwiftUI

struct OCBrandIcon: View {
    private static let image: NSImage? = Bundle.module.url(forResource: "BrandIcon", withExtension: "icns")
        .flatMap { NSImage(contentsOf: $0) }

    var body: some View {
        if let image = Self.image {
            Image(nsImage: image).resizable().scaledToFit().accessibilityHidden(true)
        }
    }
}

/// The leading categories as proportional ribbons: measured data, not a decorative progress ring.
struct HomeSpaceMap: View {
    let results: [CategoryResult]
    var onOpenCategory: (ScanCategory) -> Void
    private var ranked: [CategoryResult] {
        Array(results.filter { $0.totalBytes > 0 }.sorted { $0.totalBytes > $1.totalBytes }.prefix(4))
    }
    private var total: Int64 { results.reduce(0) { $0 + $1.totalBytes } }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text(L10n.string("overview.map_title"))
                .font(OCTheme.font(14, weight: .semibold))
            if ranked.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: results.isEmpty ? "viewfinder" : "checkmark.seal")
                        .font(.system(size: 30, weight: .ultraLight)).foregroundStyle(OCTheme.sea)
                    Text(L10n.string(results.isEmpty ? "overview.map_idle" : "overview.map_clear"))
                        .font(OCTheme.font(19, weight: .medium))
                    if results.isEmpty {
                        Text(L10n.string("overview.map_idle_body"))
                            .font(OCTheme.font(12)).foregroundStyle(OCTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }.padding(.vertical, 10)
            } else {
                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, result in
                    Button { onOpenCategory(result.category) } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 8) {
                                Text(result.category.title).lineLimit(1)
                                Spacer(minLength: 4)
                                Text(ByteFormat.string(result.totalBytes)).monospacedDigit()
                            }
                            .font(OCTheme.font(11, weight: .medium)).foregroundStyle(OCTheme.ink)
                            GeometryReader { geometry in
                                let fraction = total > 0 ? Double(result.totalBytes) / Double(total) : 0
                                ZStack(alignment: .leading) {
                                    Capsule().fill(OCTheme.ink.opacity(0.05))
                                    Capsule().fill(OCTheme.sea.opacity(1 - Double(index) * 0.18))
                                        .frame(width: max(3, geometry.size.width * fraction))
                                }
                            }.frame(height: 6)
                        }.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(result.category.title), \(ByteFormat.string(result.totalBytes))")
                }
                Text(L10n.string("overview.map_caption"))
                    .font(OCTheme.font(10)).foregroundStyle(OCTheme.muted)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
