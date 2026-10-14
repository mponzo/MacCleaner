import SwiftUI

/// Soft pulsing bone for skeleton loaders. Honors Reduce Motion.
struct OCSkeletonBone: View {
    var width: CGFloat? = nil
    var height: CGFloat = 12
    var cornerRadius: CGFloat = 6
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(OCTheme.ink.opacity(reduceMotion ? 0.10 : (pulse ? 0.14 : 0.06)))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

/// List-row skeleton matching checkbox + title/detail + trailing size.
struct OCListSkeleton: View {
    var rows: Int = 6
    var showPath: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { index in
                HStack(alignment: .top, spacing: 12) {
                    OCSkeletonBone(width: 16, height: 16, cornerRadius: 4)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 7) {
                        OCSkeletonBone(width: boneWidth(for: index, base: 160, span: 80), height: 13)
                        OCSkeletonBone(width: boneWidth(for: index, base: 220, span: 100), height: 10)
                        if showPath {
                            OCSkeletonBone(width: boneWidth(for: index, base: 280, span: 60), height: 9)
                        }
                    }
                    Spacer(minLength: 12)
                    OCSkeletonBone(width: 56, height: 13)
                }
                .padding(.vertical, 12)
                if index < rows - 1 {
                    Divider().overlay(OCTheme.stroke.opacity(0.55))
                }
            }
        }
        .padding(14)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(OCTheme.stroke, lineWidth: 1)
        )
        .accessibilityLabel(L10n.string("common.loading"))
    }

    private func boneWidth(for index: Int, base: CGFloat, span: CGFloat) -> CGFloat {
        base + CGFloat((index * 37) % Int(span))
    }
}

/// Folder / space-explorer style skeleton with proportional bars.
struct OCFolderSkeleton: View {
    var rows: Int = 7

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        OCSkeletonBone(width: 18, height: 18, cornerRadius: 5)
                        OCSkeletonBone(width: boneWidth(for: index, base: 120, span: 90), height: 12)
                        Spacer()
                        OCSkeletonBone(width: 52, height: 12)
                    }
                    OCSkeletonBone(height: 5, cornerRadius: 3)
                        .frame(maxWidth: .infinity)
                        .opacity(0.85 - Double(index) * 0.08)
                }
                .padding(.vertical, 11)
                if index < rows - 1 {
                    Divider().overlay(OCTheme.stroke.opacity(0.5))
                }
            }
        }
        .padding(14)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(OCTheme.stroke, lineWidth: 1)
        )
        .accessibilityLabel(L10n.string("common.loading"))
    }

    private func boneWidth(for index: Int, base: CGFloat, span: CGFloat) -> CGFloat {
        base + CGFloat((index * 41) % Int(span))
    }
}

/// Photo-group skeleton for Similar Photos.
struct OCPhotoSkeleton: View {
    var groups: Int = 3

    var body: some View {
        VStack(spacing: 14) {
            ForEach(0..<groups, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    OCSkeletonBone(width: 140, height: 12)
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { _ in
                            OCSkeletonBone(height: 72, cornerRadius: 10)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
                .padding(14)
                .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(OCTheme.stroke, lineWidth: 1)
                )
            }
        }
        .accessibilityLabel(L10n.string("common.loading"))
    }
}

/// Compact app-list skeleton for Applications sidebar column.
struct OCAppListSkeleton: View {
    var rows: Int = 8

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<rows, id: \.self) { index in
                HStack(spacing: 10) {
                    OCSkeletonBone(width: 28, height: 28, cornerRadius: 7)
                    VStack(alignment: .leading, spacing: 6) {
                        OCSkeletonBone(width: boneWidth(for: index, base: 100, span: 70), height: 11)
                        OCSkeletonBone(width: boneWidth(for: index, base: 70, span: 40), height: 9)
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 8)
        .accessibilityLabel(L10n.string("common.loading"))
    }

    private func boneWidth(for index: Int, base: CGFloat, span: CGFloat) -> CGFloat {
        base + CGFloat((index * 29) % Int(span))
    }
}
