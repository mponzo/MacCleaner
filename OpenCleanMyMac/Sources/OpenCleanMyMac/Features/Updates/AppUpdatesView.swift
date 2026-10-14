import SwiftUI

/// Dedicated Homebrew cask updates screen (PureMac-style “App Updates”).
struct AppUpdatesView: View {
    @Bindable var brew: HomebrewCaskEngine

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        OCPageHeader(
                            title: L10n.string("brew.page.title"),
                            subtitle: L10n.string("brew.page.subtitle")
                        )
                        Spacer(minLength: 12)
                        VStack(alignment: .trailing, spacing: 6) {
                            Button {
                                brew.refresh()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(GhostButtonStyle())
                            .disabled(brew.isBusy)
                            .help(L10n.string("brew.check"))

                            if let checked = brew.lastCheckedAt {
                                Text(L10n.format("brew.last_check", relativeTime(checked)))
                                    .font(OCTheme.font(11))
                                    .foregroundStyle(OCTheme.muted)
                            }
                        }
                    }

                    infoBanner

                    if brew.isBusy {
                        OCOperationBanner(
                            title: brew.progressLabel,
                            detail: brew.operationDetail ?? L10n.string("operation.cancel_safe"),
                            progress: brew.operationProgress.flatMap { $0 < 0 ? nil : $0 },
                            onStop: { brew.stop() }
                        )
                    }

                    if !brew.casks.isEmpty {
                        Text(L10n.format("brew.available_count", Int64(brew.casks.count)))
                            .font(OCTheme.font(15, weight: .semibold))
                    }

                    if brew.isChecking && brew.casks.isEmpty {
                        OCListSkeleton(rows: 5, showPath: false)
                    } else if brew.casks.isEmpty {
                        ContentUnavailableView(
                            L10n.string(brew.brewPath == nil ? "brew.not_found" : "brew.up_to_date"),
                            systemImage: brew.brewPath == nil ? "shippingbox" : "checkmark.seal",
                            description: Text(L10n.string(brew.brewPath == nil ? "brew.help" : "brew.empty"))
                        )
                        .frame(maxWidth: .infinity, minHeight: 160)
                    } else {
                        caskList
                    }

                    appStoreCard

                    if let err = brew.errorMessage {
                        Text(err).foregroundStyle(OCTheme.danger).font(OCTheme.font(12))
                    }
                    if let msg = brew.lastMessage {
                        Text(msg).foregroundStyle(OCTheme.success).font(OCTheme.font(12))
                    }
                }
                .padding(28)
            }

            footer
        }
        .task {
            if brew.casks.isEmpty && !brew.isBusy {
                brew.refresh()
            }
        }
    }

    private var infoBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(OCTheme.sea)
            Text(l10n: "brew.page.info")
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(OCTheme.sea.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(OCTheme.sea.opacity(0.28), lineWidth: 1)
        )
    }

    private var caskList: some View {
        VStack(spacing: 0) {
            ForEach(brew.casks) { cask in
                HStack(alignment: .top, spacing: 12) {
                    Toggle("", isOn: Binding(
                        get: { cask.isSelected },
                        set: { _ in brew.toggle(cask.id) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .disabled(brew.isBusy)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(cask.name)
                            .font(OCTheme.font(13, weight: .semibold))
                        Text(versionLine(cask))
                            .font(OCTheme.font(11))
                            .foregroundStyle(OCTheme.muted)
                        if cask.isBundleMissing {
                            Text(l10n: "brew.bundle_missing")
                                .font(OCTheme.font(11, weight: .medium))
                                .foregroundStyle(OCTheme.accent)
                        }
                    }
                    Spacer()
                    if let current = cask.currentVersion, !current.isEmpty {
                        Text(current)
                            .font(OCTheme.font(13).monospacedDigit())
                            .foregroundStyle(OCTheme.sea)
                    }
                }
                .padding(.vertical, 10)
                .opacity(brew.isUpgrading ? 0.75 : 1)
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

    private var appStoreCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n: "brew.appstore.title")
                .font(OCTheme.font(14, weight: .semibold))
            Text(l10n: "brew.appstore.body")
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.muted)
            Button {
                HomebrewCaskEngine.openAppStoreUpdates()
            } label: {
                Label(l10n: "brew.appstore.open", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(GhostButtonStyle())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OCTheme.canvasElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(OCTheme.stroke)
        )
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if brew.isUpgrading {
                OCOperationBanner(
                    title: brew.progressLabel,
                    detail: brew.operationDetail ?? L10n.string("operation.cancel_safe"),
                    progress: brew.operationProgress.flatMap { $0 < 0 ? nil : $0 },
                    onStop: { brew.stop() }
                )
            } else {
                HStack {
                    Text(
                        brew.selectedCount == 0
                            ? L10n.string("brew.select_prompt")
                            : L10n.format("brew.selected_count", Int64(brew.selectedCount))
                    )
                    .font(OCTheme.font(13))
                    .foregroundStyle(OCTheme.muted)
                    Spacer()
                    Button {
                        brew.selectAll(true)
                    } label: {
                        Text(L10n.string("common.select_all"))
                    }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(brew.casks.isEmpty || brew.isBusy)
                    Button {
                        brew.upgradeSelected()
                    } label: {
                        Label(
                            L10n.format("brew.upgrade_n", Int64(brew.selectedCount)),
                            systemImage: "arrow.up.circle"
                        )
                    }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(brew.selectedCount == 0 || brew.isBusy)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(OCTheme.canvasElevated)
        .overlay(alignment: .top) { Divider().overlay(OCTheme.stroke) }
    }

    private func versionLine(_ cask: HomebrewCaskUpdate) -> String {
        let installed = cask.installedVersions.joined(separator: ", ")
        if let current = cask.currentVersion, !current.isEmpty {
            return L10n.format(
                "brew.version_line",
                installed.isEmpty ? "—" : installed,
                current
            )
        }
        return installed.isEmpty ? cask.token : installed
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
