import SwiftUI

struct SpaceExplorerView: View {
    @Bindable var explorer: SpaceExplorerEngine
    @Bindable var engine: ScanEngine

    private var maxBytes: Int64 {
        max(explorer.children.first?.byteCount ?? 1, 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    OCPageHeader(
                        title: L10n.string("space.title"),
                        subtitle: L10n.string("space.subtitle")
                    )

                    controls
                    breadcrumbBar

                    if explorer.isScanning {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(explorer.progressLabel)
                                Spacer()
                                Button(L10n.string("smartcare.stop")) { explorer.stop() }
                                    .buttonStyle(GhostButtonStyle())
                            }
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    if let error = explorer.errorMessage {
                        Text(error).foregroundStyle(OCTheme.danger)
                    }

                    if explorer.rootURL == nil {
                        emptyPrompt
                    } else if explorer.children.isEmpty && !explorer.isScanning {
                        ContentUnavailableView(
                            L10n.string("space.explorer.empty"),
                            systemImage: "folder",
                            description: Text(l10n: "space.explorer.empty.detail")
                        )
                        .frame(maxWidth: .infinity, minHeight: 180)
                    } else if !explorer.children.isEmpty {
                        folderList
                    }

                    if !engine.results.isEmpty {
                        Divider().overlay(OCTheme.stroke)
                        smartCareBreakdown
                    }
                }
                .padding(28)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                explorer.chooseFolder()
            } label: {
                Label(l10n: "space.explorer.choose", systemImage: "folder.badge.plus")
            }
            .buttonStyle(SeaButtonStyle())
            .disabled(explorer.isScanning)

            Button(L10n.string("space.explorer.home")) {
                explorer.openHome()
            }
            .buttonStyle(GhostButtonStyle())
            .disabled(explorer.isScanning)

            Button(L10n.string("space.explorer.applications")) {
                explorer.openApplications()
            }
            .buttonStyle(GhostButtonStyle())
            .disabled(explorer.isScanning)

            if explorer.rootURL != nil {
                Button(L10n.string("space.explorer.parent")) {
                    explorer.openParent()
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(explorer.isScanning)

                Button(L10n.string("common.refresh")) {
                    explorer.refresh()
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(explorer.isScanning)

                Button(L10n.string("settings.reveal")) {
                    explorer.revealCurrent()
                }
                .buttonStyle(GhostButtonStyle())
            }

            Spacer()

            if explorer.rootURL != nil {
                Text(ByteFormat.string(explorer.totalBytes))
                    .font(OCTheme.font(14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(OCTheme.sea)
            }
        }
    }

    private var breadcrumbBar: some View {
        Group {
            if !explorer.breadcrumb.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(explorer.breadcrumb.enumerated()), id: \.offset) { index, url in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(OCTheme.font(10))
                                    .foregroundStyle(OCTheme.faint)
                            }
                            Button(url.lastPathComponent.isEmpty ? "/" : url.lastPathComponent) {
                                explorer.open(url)
                            }
                            .buttonStyle(.plain)
                            .font(OCTheme.font(12, weight: index == explorer.breadcrumb.count - 1 ? .semibold : .regular))
                            .foregroundStyle(index == explorer.breadcrumb.count - 1 ? OCTheme.ink : OCTheme.sea)
                            .disabled(explorer.isScanning)
                        }
                    }
                }
            }
        }
    }

    private var emptyPrompt: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(l10n: "space.explorer.prompt")
                .font(OCTheme.font(15, weight: .semibold))
            Text(l10n: "space.explorer.prompt.detail")
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.muted)
            Text(l10n: "space.explorer.read_only")
                .font(OCTheme.font(11))
                .foregroundStyle(OCTheme.faint)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(OCTheme.stroke)
        )
    }

    private var folderList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(explorer.children) { node in
                Button {
                    explorer.drill(into: node)
                } label: {
                    nodeRow(node)
                }
                .buttonStyle(.plain)
                .disabled(explorer.isScanning)
            }
        }
        .padding(16)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(OCTheme.stroke)
        )
    }

    private func nodeRow(_ node: SpaceNode) -> some View {
        let ratio = max(0.03, CGFloat(node.byteCount) / CGFloat(maxBytes))
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: node.isDirectory ? "folder.fill" : "doc")
                    .foregroundStyle(OCTheme.sea)
                    .frame(width: 18)
                Text(node.name)
                    .font(OCTheme.font(13, weight: .medium))
                    .foregroundStyle(OCTheme.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(ByteFormat.string(node.byteCount))
                    .font(OCTheme.font(13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(OCTheme.ink)
                if node.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(OCTheme.font(11))
                        .foregroundStyle(OCTheme.muted)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(OCTheme.sea.opacity(0.85))
                        .frame(width: geo.size.width * ratio)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var smartCareBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n: "space.scan_breakdown")
                .font(OCTheme.font(15, weight: .semibold))
            Text(l10n: "space.scan_breakdown.detail")
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.muted)

            let slices = engine.results
                .filter { $0.totalBytes > 0 }
                .sorted { $0.totalBytes > $1.totalBytes }
            let peak = max(slices.first?.totalBytes ?? 1, 1)

            ForEach(slices) { result in
                let ratio = max(0.04, CGFloat(result.totalBytes) / CGFloat(peak))
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: result.category.systemImage)
                            .foregroundStyle(OCTheme.sea)
                        Text(result.category.title)
                        Spacer()
                        Text(ByteFormat.string(result.totalBytes))
                            .font(.body.monospacedDigit().weight(.semibold))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [OCTheme.accent, OCTheme.sea],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: geo.size.width * ratio)
                        }
                    }
                    .frame(height: 10)
                }
            }
        }
        .padding(16)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(OCTheme.stroke)
        )
    }
}
