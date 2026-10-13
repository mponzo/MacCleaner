import SwiftUI

struct ApplicationsView: View {
    @Bindable var uninstaller: UninstallerEngine

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            appList
                .frame(width: 300)
                .frame(maxHeight: .infinity)

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            if uninstaller.apps.isEmpty {
                await uninstaller.refresh()
            } else if uninstaller.selectedAppID == nil {
                uninstaller.selectedAppID = uninstaller.filteredApps.first?.id
            }
        }
    }

    private var appList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField(L10n.string("apps.search"), text: $uninstaller.query)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await uninstaller.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(uninstaller.isLoading || uninstaller.isUninstalling)
            }
            .padding(12)

            Divider().opacity(0.25)

            if uninstaller.isLoading {
                VStack(spacing: 12) {
                    OCShimmerBar(height: 4)
                        .padding(.horizontal, 40)
                    ProgressView()
                        .controlSize(.small)
                        .tint(OCTheme.sea)
                    Text(uninstaller.progressLabel)
                        .font(.caption)
                        .foregroundStyle(OCTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if uninstaller.filteredApps.isEmpty {
                ContentUnavailableView(
                    L10n.string("apps.select"),
                    systemImage: "magnifyingglass",
                    description: Text(l10n: "apps.select.detail")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(uninstaller.filteredApps) { app in
                            appRow(app)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
        }
        .background { panelBackground }
    }

    private func appRow(_ app: InstalledApp) -> some View {
        let selected = uninstaller.selectedAppID == app.id
        return Button {
            uninstaller.selectedAppID = app.id
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OCTheme.ink)
                        .lineLimit(1)
                    Text(app.bundleIdentifier)
                        .font(.system(size: 10))
                        .foregroundStyle(OCTheme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ByteFormat.string(app.byteCount))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(OCTheme.ink)
                    if app.leftoverBytes > 0 {
                        Text("+\(ByteFormat.string(app.leftoverBytes))")
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(OCTheme.accent)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? OCTheme.sea.opacity(0.22) : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? OCTheme.sea.opacity(0.45) : Color.clear, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detail: some View {
        if let app = uninstaller.selectedApp {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(app)
                    leftoversSection(app)
                    orphansSection
                    if let result = uninstaller.lastResult {
                        Text(L10n.format("apps.last_action", Int64(result.movedCount), ByteFormat.string(result.freedBytes)))
                            .font(.callout)
                            .foregroundStyle(OCTheme.muted)
                    }
                    if let error = uninstaller.errorMessage {
                        Text(error).foregroundStyle(OCTheme.danger)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background { panelBackground }
        } else {
            ContentUnavailableView(
                L10n.string("apps.select"),
                systemImage: "app.badge.checkmark",
                description: Text(l10n: "apps.select.detail")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { panelBackground }
            .foregroundStyle(OCTheme.ink)
        }
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(OCTheme.glass.opacity(0.18))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
    }

    private func header(_ app: InstalledApp) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(app.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(OCTheme.ink)

            Text("\(app.bundleIdentifier) · v\(app.version)")
                .font(.system(size: 12))
                .foregroundStyle(OCTheme.muted)

            HStack(spacing: 20) {
                labeled(L10n.string("apps.app_size"), ByteFormat.string(app.byteCount))
                labeled(L10n.string("apps.leftovers_size"), ByteFormat.string(app.leftoverBytes))
                labeled(L10n.string("apps.selected_size"), ByteFormat.string(app.uninstallBytes))
            }

            if app.isProtected {
                Text(l10n: "apps.protected")
                    .foregroundStyle(OCTheme.accent)
            } else {
                Toggle(L10n.string("apps.include_bundle"), isOn: Binding(
                    get: { app.includeAppBundle },
                    set: { _ in uninstaller.toggleIncludeBundle(appID: app.id) }
                ))

                Button {
                    Task { await uninstaller.uninstallSelectedApp() }
                } label: {
                    Label(l10n: "apps.uninstall_selected", systemImage: "trash")
                        .frame(minWidth: 160)
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(uninstaller.isUninstalling || app.uninstallBytes == 0)
            }
        }
    }

    private func leftoversSection(_ app: InstalledApp) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n: "apps.leftovers")
                .font(.headline)
            if app.leftovers.isEmpty {
                Text(l10n: "apps.leftovers.empty")
                    .foregroundStyle(OCTheme.muted)
            } else {
                ForEach(app.leftovers) { leftover in
                    HStack(alignment: .top) {
                        Toggle("", isOn: Binding(
                            get: { leftover.isSelected },
                            set: { _ in uninstaller.toggleLeftover(appID: app.id, leftoverID: leftover.id) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                        .disabled(app.isProtected)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(leftover.kind.title) · \(leftover.url.lastPathComponent)")
                                .font(.body.weight(.medium))
                            Text(leftover.url.path)
                                .font(.caption)
                                .foregroundStyle(OCTheme.muted)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text(ByteFormat.string(leftover.byteCount))
                            .font(.body.monospacedDigit())
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var orphansSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(l10n: "apps.orphans")
                    .font(.headline)
                Spacer()
                Button(L10n.string("apps.clean_orphans")) {
                    Task { await uninstaller.cleanSelectedOrphans() }
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(uninstaller.orphanBytes == 0 || uninstaller.isUninstalling)
            }
            Text(l10n: "apps.orphans.detail")
                .font(.caption)
                .foregroundStyle(OCTheme.muted)

            ForEach(uninstaller.orphanLeftovers.prefix(25)) { leftover in
                HStack(alignment: .top) {
                    Toggle("", isOn: Binding(
                        get: { leftover.isSelected },
                        set: { _ in uninstaller.toggleOrphan(leftover.id) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.checkbox)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(leftover.kind.title) · \(leftover.url.lastPathComponent)")
                        Text(leftover.url.path)
                            .font(.caption)
                            .foregroundStyle(OCTheme.muted)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(ByteFormat.string(leftover.byteCount))
                        .monospacedDigit()
                }
            }
        }
        .padding(.top, 8)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(OCTheme.muted)
            Text(value)
                .font(.system(size: 18, weight: .semibold).monospacedDigit())
        }
    }
}
