import SwiftUI

/// Compact Homebrew block embedded under MacCleaner self-updates.
struct HomebrewCaskSection: View {
    @Bindable var brew: HomebrewCaskEngine
    var onOpenFullPage: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l10n: "brew.title")
                    .font(OCTheme.font(15, weight: .semibold))
                Spacer()
                if let onOpenFullPage {
                    Button(L10n.string("brew.open_page"), action: onOpenFullPage)
                        .buttonStyle(.plain)
                        .foregroundStyle(OCTheme.sea)
                        .font(OCTheme.font(12, weight: .medium))
                }
            }
            Text(l10n: "brew.help")
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.muted)

            if brew.isBusy {
                OCOperationBanner(
                    title: brew.progressLabel,
                    detail: brew.operationDetail ?? L10n.string("operation.cancel_safe"),
                    progress: brew.operationProgress.flatMap { $0 < 0 ? nil : $0 },
                    onStop: { brew.stop() }
                )
            } else {
                HStack(spacing: 10) {
                    Button {
                        brew.refresh()
                    } label: {
                        Label(l10n: "brew.check", systemImage: "shippingbox")
                    }
                    .buttonStyle(GhostButtonStyle())

                    Button {
                        brew.upgradeSelected()
                    } label: {
                        Label(l10n: "brew.upgrade", systemImage: "arrow.up.circle")
                    }
                    .buttonStyle(SeaButtonStyle())
                    .disabled(brew.selectedCount == 0)
                }
            }

            Text(brew.progressLabel)
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.muted)

            if brew.casks.isEmpty && !brew.isChecking {
                Text(l10n: "brew.empty")
                    .foregroundStyle(OCTheme.muted)
            } else {
                ForEach(brew.casks.prefix(5)) { cask in
                    HStack(alignment: .top, spacing: 10) {
                        Toggle("", isOn: Binding(
                            get: { cask.isSelected },
                            set: { _ in brew.toggle(cask.id) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                        .disabled(brew.isBusy)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(cask.name)
                                .font(OCTheme.font(13, weight: .medium))
                            Text(versionLine(cask))
                                .font(OCTheme.font(11))
                                .foregroundStyle(OCTheme.muted)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                if brew.casks.count > 5, let onOpenFullPage {
                    Button(L10n.format("brew.more", Int64(brew.casks.count - 5)), action: onOpenFullPage)
                        .buttonStyle(.plain)
                        .foregroundStyle(OCTheme.sea)
                        .font(OCTheme.font(12))
                }
            }

            if let err = brew.errorMessage {
                Text(err).foregroundStyle(OCTheme.danger).font(OCTheme.font(12))
            }
            if let msg = brew.lastMessage {
                Text(msg).foregroundStyle(OCTheme.success).font(OCTheme.font(12))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(OCTheme.violet.opacity(0.22))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                }
        }
    }

    private func versionLine(_ cask: HomebrewCaskUpdate) -> String {
        let installed = cask.installedVersions.joined(separator: ", ")
        if let current = cask.currentVersion, !current.isEmpty {
            return "\(installed.isEmpty ? "—" : installed) → \(current)"
        }
        return installed.isEmpty ? cask.token : installed
    }
}
