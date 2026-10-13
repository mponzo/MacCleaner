import AppKit
import SwiftUI

struct DuplicateFinderView: View {
    @Bindable var engine: DuplicateFinderEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                OCPageHeader(
                    title: L10n.string("dup.title"),
                    subtitle: L10n.string("dup.subtitle")
                )

                HStack(spacing: 10) {
                    Button {
                        engine.chooseFolder()
                    } label: {
                        Label(l10n: "dup.choose", systemImage: "folder")
                            .frame(minWidth: 140)
                    }
                    .buttonStyle(SeaButtonStyle())
                    .disabled(engine.isScanning || engine.isCleaning)

                    if engine.rootURL != nil {
                        Button {
                            engine.startScan()
                        } label: {
                            Label(l10n: "dup.rescan", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(GhostButtonStyle())
                        .disabled(engine.isScanning || engine.isCleaning)
                    }

                    Button {
                        engine.cleanSelected()
                    } label: {
                        Label(l10n: "dup.trash_selected", systemImage: "trash")
                            .frame(minWidth: 150)
                    }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(engine.isScanning || engine.isCleaning || engine.reclaimableBytes == 0)

                    if engine.isScanning || engine.isCleaning {
                        Button {
                            engine.stop()
                        } label: {
                            Label(l10n: "smartcare.stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(GhostButtonStyle())
                        ProgressView().controlSize(.small).tint(OCTheme.sea)
                    }

                    Spacer()
                    Text(ByteFormat.string(engine.reclaimableBytes))
                        .font(.system(size: 16, weight: .semibold).monospacedDigit())
                        .foregroundStyle(engine.reclaimableBytes > 0 ? OCTheme.accent : OCTheme.muted)
                }

                if let root = engine.rootURL {
                    Text(root.path)
                        .font(.caption)
                        .foregroundStyle(OCTheme.muted)
                        .lineLimit(2)
                }

                Text(engine.progressLabel)
                    .font(.callout)
                    .foregroundStyle(OCTheme.muted)

                if engine.skippedCount > 0 {
                    Text(L10n.format("dup.skipped", Int64(engine.skippedCount)))
                        .font(.caption)
                        .foregroundStyle(OCTheme.faint)
                }

                if let error = engine.errorMessage {
                    Text(error).foregroundStyle(OCTheme.danger)
                }

                if engine.groups.isEmpty, !engine.isScanning {
                    ContentUnavailableView(
                        L10n.string("dup.empty"),
                        systemImage: "doc.on.doc",
                        description: Text(l10n: "dup.empty.detail")
                    )
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    ForEach(engine.groups) { group in
                        groupCard(group)
                    }
                }
            }
            .padding(28)
        }
    }

    private func groupCard(_ group: DuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.format("dup.group_title", Int64(group.files.count)))
                    .font(.headline)
                Spacer()
                Text(ByteFormat.string(group.reclaimableBytes))
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(OCTheme.accent)
            }

            ForEach(group.files) { file in
                HStack(alignment: .top, spacing: 10) {
                    Toggle("", isOn: Binding(
                        get: { file.isSelected },
                        set: { _ in engine.toggle(groupID: group.id, fileID: file.id) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .disabled(file.isProtected || engine.isCleaning)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(file.url.lastPathComponent)
                                .font(.body.weight(.medium))
                            if file.isProtected {
                                Text(l10n: "dup.protected")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(OCTheme.sea.opacity(0.2), in: Capsule())
                                    .foregroundStyle(OCTheme.sea)
                            }
                        }
                        Text(file.url.path)
                            .font(.caption)
                            .foregroundStyle(OCTheme.muted)
                            .lineLimit(2)
                    }
                    Spacer()
                    Text(ByteFormat.string(file.byteCount))
                        .font(.callout.monospacedDigit())
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([file.url])
                    } label: {
                        Image(systemName: "eye")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .help(L10n.string("dup.reveal"))
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                }
        }
    }
}
