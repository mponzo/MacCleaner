import AppKit
import SwiftUI

struct DeveloperCleanupView: View {
    @Bindable var engine: DeveloperCleanupEngine

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    OCPageHeader(
                        title: L10n.string("dev.title"),
                        subtitle: L10n.string("dev.subtitle")
                    )

                    HStack(spacing: 10) {
                        Button {
                            Task { await engine.refresh() }
                        } label: {
                            Label(l10n: "dev.scan", systemImage: "hammer")
                        }
                        .buttonStyle(SeaButtonStyle())
                        .disabled(engine.isScanning || engine.isCleaning)

                        Button(L10n.string("common.select_all")) { engine.selectAll(true) }
                            .buttonStyle(GhostButtonStyle())
                            .disabled(engine.targets.isEmpty)
                        Button(L10n.string("common.select_none")) { engine.selectAll(false) }
                            .buttonStyle(GhostButtonStyle())
                            .disabled(engine.targets.isEmpty)

                        Spacer()
                        Text(engine.progressLabel)
                            .font(OCTheme.font(12))
                            .foregroundStyle(OCTheme.muted)
                    }

                    if engine.isScanning {
                        ProgressView().controlSize(.small)
                    }

                    if engine.targets.isEmpty && !engine.isScanning {
                        ContentUnavailableView(
                            L10n.string("dev.empty"),
                            systemImage: "hammer",
                            description: Text(l10n: "dev.empty.detail")
                        )
                        .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(engine.targets) { target in
                                HStack(alignment: .top, spacing: 12) {
                                    Toggle("", isOn: Binding(
                                        get: { target.isSelected },
                                        set: { _ in engine.toggle(target.id) }
                                    ))
                                    .labelsHidden()
                                    .toggleStyle(.checkbox)
                                    .disabled(engine.isCleaning)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(target.name)
                                            .font(OCTheme.font(13, weight: .semibold))
                                        Text(target.detail)
                                            .font(OCTheme.font(11))
                                            .foregroundStyle(OCTheme.muted)
                                        Text(target.url.path)
                                            .font(OCTheme.font(11))
                                            .foregroundStyle(OCTheme.faint)
                                            .lineLimit(1)
                                            .textSelection(.enabled)
                                    }
                                    Spacer()
                                    Text(ByteFormat.string(target.byteCount))
                                        .font(OCTheme.font(13).monospacedDigit())
                                    Button {
                                        NSWorkspace.shared.activateFileViewerSelecting([target.url])
                                    } label: {
                                        Image(systemName: "folder")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(OCTheme.sea)
                                }
                                .padding(.vertical, 10)
                                .overlay(alignment: .bottom) {
                                    Divider().overlay(OCTheme.stroke.opacity(0.6))
                                }
                            }
                        }
                        .padding(14)
                        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(OCTheme.stroke)
                        )
                    }

                    if let error = engine.errorMessage {
                        Text(error).foregroundStyle(OCTheme.danger)
                    }
                }
                .padding(28)
            }

            if !engine.targets.isEmpty {
                HStack {
                    Text(ByteFormat.string(engine.selectedBytes))
                        .font(OCTheme.font(16, weight: .semibold).monospacedDigit())
                    Text(l10n: "dev.selected")
                        .foregroundStyle(OCTheme.muted)
                    Spacer()
                    Button {
                        Task { await engine.cleanSelected() }
                    } label: {
                        Label(l10n: "dev.clean", systemImage: "trash")
                    }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(engine.selectedBytes == 0 || engine.isCleaning || engine.isScanning)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(OCTheme.canvasElevated)
                .overlay(alignment: .top) { Divider().overlay(OCTheme.stroke) }
            }
        }
        .task {
            if engine.targets.isEmpty {
                await engine.refresh()
            }
        }
    }
}
