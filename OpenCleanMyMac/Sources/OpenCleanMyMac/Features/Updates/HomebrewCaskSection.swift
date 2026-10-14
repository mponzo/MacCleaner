import SwiftUI

struct HomebrewCaskSection: View {
    @Bindable var brew: HomebrewCaskEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n: "brew.title")
                .font(OCTheme.font(15, weight: .semibold))
            Text(l10n: "brew.help")
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.muted)

            HStack(spacing: 10) {
                Button {
                    Task { await brew.refresh() }
                } label: {
                    Label(l10n: "brew.check", systemImage: "shippingbox")
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(brew.isChecking || brew.isUpgrading)

                Button {
                    Task { await brew.upgradeSelected() }
                } label: {
                    Label(l10n: "brew.upgrade", systemImage: "arrow.up.circle")
                }
                .buttonStyle(SeaButtonStyle())
                .disabled(brew.selectedCount == 0 || brew.isChecking || brew.isUpgrading)

                if brew.isChecking || brew.isUpgrading {
                    ProgressView().controlSize(.small).tint(OCTheme.sea)
                }
            }

            Text(brew.progressLabel)
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.muted)

            if let path = brew.brewPath {
                Text(path)
                    .font(OCTheme.font(11))
                    .foregroundStyle(OCTheme.faint)
                    .textSelection(.enabled)
            }

            if brew.casks.isEmpty && !brew.isChecking {
                Text(l10n: "brew.empty")
                    .foregroundStyle(OCTheme.muted)
            } else {
                ForEach(brew.casks) { cask in
                    HStack(alignment: .top, spacing: 10) {
                        Toggle("", isOn: Binding(
                            get: { cask.isSelected },
                            set: { _ in brew.toggle(cask.id) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                        .disabled(brew.isUpgrading)

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
