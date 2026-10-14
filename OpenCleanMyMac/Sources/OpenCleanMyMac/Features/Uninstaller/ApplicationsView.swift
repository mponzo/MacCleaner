import SwiftUI
import UniformTypeIdentifiers

struct ApplicationsView: View {
    @Bindable var uninstaller: UninstallerEngine
    @State private var confirmUninstall = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            dropHint
            HStack(alignment: .top, spacing: 14) {
                appList
                    .frame(width: 300)
                    .frame(maxHeight: .infinity)

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    uninstaller.isDropTargeted ? OCTheme.sea : Color.clear,
                    lineWidth: 2
                )
                .padding(6)
        }
        .onDrop(of: [.fileURL], isTargeted: $uninstaller.isDropTargeted) { providers in
            uninstaller.handleDroppedProviders(providers)
        }
        .task {
            if uninstaller.apps.isEmpty {
                uninstaller.refresh()
            } else if uninstaller.selectedAppID == nil {
                uninstaller.selectedAppID = uninstaller.filteredApps.first?.id
            }
        }
        .confirmationDialog(
            L10n.string("apps.confirm_title"),
            isPresented: $confirmUninstall,
            titleVisibility: .visible
        ) {
            Button(L10n.string("apps.uninstall_selected"), role: .destructive) {
                Task { await uninstaller.uninstallSelectedApp() }
            }
            Button(L10n.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(l10n: "apps.confirm_body")
        }
    }

    private var dropHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "app.dashed")
                .foregroundStyle(OCTheme.sea)
            Text(l10n: "apps.drop.hint")
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.muted)
            Spacer()
            Picker("", selection: Binding(
                get: { uninstaller.matchSensitivity },
                set: { uninstaller.setMatchSensitivity($0) }
            )) {
                ForEach(LeftoverMatchSensitivity.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            .help(uninstaller.matchSensitivity.detail)
        }
        .padding(.horizontal, 4)
    }

    private var appList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField(L10n.string("apps.search"), text: $uninstaller.query)
                    .textFieldStyle(.roundedBorder)
                Button {
                    uninstaller.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(uninstaller.isBusy)
            }
            .padding(12)

            Divider().opacity(0.25)

            if uninstaller.isLoading {
                VStack(alignment: .leading, spacing: 12) {
                    OCOperationBanner(
                        title: uninstaller.progressLabel,
                        detail: L10n.string("operation.cancel_safe"),
                        progress: nil,
                        onStop: { uninstaller.stop() }
                    )
                    .padding(.horizontal, 14)
                    OCAppListSkeleton(rows: 9)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 8)
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
                        .font(OCTheme.font(13, weight: .semibold))
                        .foregroundStyle(OCTheme.ink)
                        .lineLimit(1)
                    Text(app.bundleIdentifier)
                        .font(OCTheme.font(10))
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
                .font(OCTheme.font(28, weight: .bold))
                .foregroundStyle(OCTheme.ink)

            Text("\(app.bundleIdentifier) · v\(app.version)")
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.muted)

            HStack(spacing: 20) {
                labeled(L10n.string("apps.app_size"), ByteFormat.string(app.byteCount))
                labeled(L10n.string("apps.leftovers_size"), ByteFormat.string(app.leftoverBytes))
                labeled(L10n.string("apps.selected_size"), ByteFormat.string(app.uninstallBytes))
            }

            if uninstaller.isUninstalling {
                OCOperationBanner(
                    title: uninstaller.progressLabel,
                    detail: nil,
                    progress: nil,
                    onStop: nil
                )
            } else if app.isProtected {
                Text(l10n: "apps.protected")
                    .foregroundStyle(OCTheme.accent)
            } else {
                Toggle(L10n.string("apps.include_bundle"), isOn: Binding(
                    get: { app.includeAppBundle },
                    set: { _ in uninstaller.toggleIncludeBundle(appID: app.id) }
                ))

                Button {
                    confirmUninstall = true
                } label: {
                    Label(l10n: "apps.uninstall_selected", systemImage: "trash")
                        .frame(minWidth: 160)
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(uninstaller.isBusy || app.uninstallBytes == 0)
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
                .font(OCTheme.font(10, weight: .semibold))
                .foregroundStyle(OCTheme.muted)
            Text(value)
                .font(.system(size: 18, weight: .semibold).monospacedDigit())
        }
    }
}
