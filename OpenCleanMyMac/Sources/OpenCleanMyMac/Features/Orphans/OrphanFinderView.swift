import AppKit
import SwiftUI

struct OrphanFinderView: View {
    @Bindable var engine: OrphanFinderEngine

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    OCPageHeader(
                        title: L10n.string("orphan.title"),
                        subtitle: L10n.string("orphan.subtitle")
                    )

                    HStack(spacing: 10) {
                        Button {
                            engine.refresh()
                        } label: {
                            Label(l10n: "orphan.scan", systemImage: "magnifyingglass")
                        }
                        .buttonStyle(SeaButtonStyle())
                        .disabled(engine.isBusy)

                        Button(L10n.string("common.select_all")) {
                            engine.selectAll(true)
                        }
                        .buttonStyle(GhostButtonStyle())
                        .disabled(engine.orphans.isEmpty || engine.isBusy)

                        Button(L10n.string("common.select_none")) {
                            engine.selectAll(false)
                        }
                        .buttonStyle(GhostButtonStyle())
                        .disabled(engine.orphans.isEmpty || engine.isBusy)

                        Spacer()

                        if !engine.isBusy {
                            Text(engine.progressLabel)
                                .font(OCTheme.font(12))
                                .foregroundStyle(OCTheme.muted)
                        }
                    }

                    if engine.isBusy {
                        OCOperationBanner(
                            title: engine.progressLabel,
                            detail: engine.operationDetail ?? L10n.string("operation.cancel_safe"),
                            progress: engine.operationProgress.flatMap { $0 < 0 ? nil : $0 },
                            onStop: { engine.stop() }
                        )
                    }

                    if engine.isLoading {
                        OCListSkeleton(rows: 6, showPath: true)
                    } else if engine.orphans.isEmpty {
                        ContentUnavailableView(
                            L10n.string("orphan.empty"),
                            systemImage: "checkmark.seal",
                            description: Text(l10n: "orphan.empty.detail")
                        )
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(engine.orphans) { leftover in
                                orphanRow(leftover)
                            }
                        }
                        .padding(12)
                        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(OCTheme.stroke)
                        )
                    }

                    if let error = engine.errorMessage {
                        Text(error).foregroundStyle(OCTheme.danger)
                    }
                    if let result = engine.lastResult {
                        Text(L10n.format("smartcare.freed", ByteFormat.string(result.freedBytes)))
                            .foregroundStyle(OCTheme.muted)
                    }
                }
                .padding(28)
            }

            if !engine.orphans.isEmpty || engine.isCleaning {
                VStack(alignment: .leading, spacing: 10) {
                    if engine.isCleaning {
                        OCOperationBanner(
                            title: engine.progressLabel,
                            detail: engine.operationDetail ?? L10n.string("operation.cancel_safe"),
                            progress: engine.operationProgress.flatMap { $0 < 0 ? nil : $0 },
                            onStop: { engine.stop() }
                        )
                    } else {
                        HStack {
                            Text(L10n.format("orphan.selected", Int64(engine.selectedCount), ByteFormat.string(engine.selectedBytes)))
                                .font(OCTheme.font(14, weight: .semibold))
                            Spacer()
                            Button {
                                engine.cleanSelected()
                            } label: {
                                Label(l10n: "orphan.clean", systemImage: "trash")
                            }
                            .buttonStyle(AccentButtonStyle())
                            .disabled(engine.selectedBytes == 0 || engine.isBusy)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(OCTheme.canvasElevated)
                .overlay(alignment: .top) { Divider().overlay(OCTheme.stroke) }
            }
        }
        .task {
            if engine.orphans.isEmpty {
                engine.refresh()
            }
        }
    }

    private func orphanRow(_ leftover: AppLeftover) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: Binding(
                get: { leftover.isSelected },
                set: { _ in engine.toggle(leftover.id) }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)
            .disabled(engine.isBusy)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(leftover.kind.title) · \(leftover.url.lastPathComponent)")
                    .font(OCTheme.font(13, weight: .medium))
                Text(leftover.url.path)
                    .font(OCTheme.font(11))
                    .foregroundStyle(OCTheme.muted)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            Spacer()
            Text(ByteFormat.string(leftover.byteCount))
                .font(OCTheme.font(13).monospacedDigit())
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([leftover.url])
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.plain)
            .foregroundStyle(OCTheme.sea)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider().overlay(OCTheme.stroke.opacity(0.6)) }
    }
}
