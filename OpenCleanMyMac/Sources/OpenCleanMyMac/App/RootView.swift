import SwiftUI

struct RootView: View {
    @Bindable var engine: ScanEngine
    @Bindable var uninstaller: UninstallerEngine
    @Bindable var performance: PerformanceEngine
    @Bindable var privileged: PrivilegedHelperEngine
    @Bindable var updater: AppUpdateEngine
    @Bindable var preferences: AppPreferences
    @State private var destination: SidebarDestination = .overview

    var body: some View {
        ZStack {
            OCScreenBackground()
            NavigationSplitView {
                sidebar
                    .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
            } detail: {
                detail
            }
            .navigationTitle(L10n.string("app.name"))
        }
        .preferredColorScheme(.dark)
        .tint(OCTheme.sea)
        .foregroundStyle(OCTheme.ink)
        .frame(minWidth: 980, minHeight: 640)
        .id(preferences.languageRevision)
        .onAppear {
            preferences.finishLaunchSetup()
        }
        .onReceive(NotificationCenter.default.publisher(for: .ocmmOpenSettings)) { _ in
            destination = .settings
        }
        .onReceive(NotificationCenter.default.publisher(for: .ocmmOpenPerformance)) { _ in
            destination = .performance
        }
        .onReceive(
            DistributedNotificationCenter.default()
                .publisher(for: Notification.Name("com.maccleaner.activate"))
        ) { _ in
            preferences.hideDockIcon = false
            preferences.applyActivationPolicy()
            NSApp.activate(ignoringOtherApps: true)
            destination = .overview
        }
    }

    private var sidebar: some View {
        List(selection: $destination) {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n: "sidebar.overview")
                            .font(.system(size: 13, weight: .semibold))
                        Text(engine.isScanning ? engine.progressLabel : L10n.string("sidebar.overview.subtitle"))
                            .font(.system(size: 11))
                            .foregroundStyle(OCTheme.muted)
                            .lineLimit(2)
                    }
                } icon: {
                    Image(systemName: "sparkles")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(OCTheme.sea)
                }
                .tag(SidebarDestination.overview)
            } header: {
                Text(l10n: "sidebar.smart_care")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OCTheme.faint)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Section {
                sidebarItem("sidebar.applications", icon: "app.badge.checkmark", tag: .applications)
                sidebarItem("sidebar.performance", icon: "gauge.with.dots.needle.67percent", tag: .performance)
                sidebarItem("sidebar.privileged", icon: "lock.shield", tag: .privileged)
                sidebarItem("sidebar.space_lens", icon: "chart.bar.fill", tag: .spaceLens)
                sidebarItem("sidebar.updates", icon: "arrow.down.app", tag: .updates)
                sidebarItem("sidebar.settings", icon: "gearshape", tag: .settings)
            } header: {
                Text(l10n: "sidebar.tools")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OCTheme.faint)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            if !engine.results.isEmpty {
                Section {
                    ForEach(engine.results) { result in
                        Label {
                            HStack(spacing: 8) {
                                Text(result.category.title)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(ByteFormat.string(result.totalBytes))
                                    .font(.system(size: 11).monospacedDigit())
                                    .foregroundStyle(OCTheme.muted)
                            }
                        } icon: {
                            Image(systemName: result.category.systemImage)
                                .foregroundStyle(OCTheme.sea.opacity(0.9))
                        }
                        .tag(SidebarDestination.category(result.category))
                    }
                } header: {
                    Text(l10n: "sidebar.modules")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(OCTheme.faint)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(OCTheme.sidebarFill.opacity(0.65))
        .foregroundStyle(OCTheme.ink)
    }

    private func sidebarItem(_ key: String, icon: String, tag: SidebarDestination) -> some View {
        Label {
            Text(L10n.string(key: key))
                .font(.system(size: 13, weight: .medium))
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(OCTheme.sea.opacity(0.95))
        }
        .tag(tag)
    }

    @ViewBuilder
    private var detail: some View {
        switch destination {
        case .overview:
            SmartCareView(engine: engine) { category in
                destination = .category(category)
            }
        case .applications:
            ApplicationsView(uninstaller: uninstaller)
        case .performance:
            PerformanceView(performance: performance)
        case .privileged:
            PrivilegedHelperView(privileged: privileged)
        case .spaceLens:
            SpaceLensView(engine: engine)
        case .updates:
            UpdatesView(updater: updater, preferences: preferences)
        case .settings:
            SettingsView(preferences: preferences)
        case .category(let category):
            if let result = engine.results.first(where: { $0.category == category }) {
                CategoryDetailView(engine: engine, result: result)
            } else {
                ContentUnavailableView(L10n.string("smartcare.run_prompt"), systemImage: "sparkles")
            }
        }
    }
}

struct SmartCareView: View {
    @Bindable var engine: ScanEngine
    var onOpenCategory: (ScanCategory) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                hero
                actions
                if !engine.results.isEmpty {
                    moduleGrid
                }
                if let clean = engine.lastCleanResult {
                    Text(L10n.format("smartcare.last_clean", clean.movedCount, ByteFormat.string(clean.freedBytes)))
                        .font(.callout)
                        .foregroundStyle(OCTheme.muted)
                }
                if let error = engine.errorMessage {
                    Text(error).foregroundStyle(OCTheme.danger)
                }
            }
            .padding(28)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            OCPageHeader(
                title: L10n.string("smartcare.title"),
                subtitle: L10n.string("smartcare.subtitle")
            )

            HStack(spacing: 10) {
                OCMetricChip(
                    title: L10n.string("smartcare.reclaimable"),
                    value: ByteFormat.string(engine.reclaimableBytes),
                    emphasize: engine.reclaimableBytes > 0
                )
                OCMetricChip(
                    title: L10n.string("smartcare.scanned"),
                    value: ByteFormat.string(engine.scannedBytes)
                )
                OCMetricChip(
                    title: L10n.string("smartcare.progress"),
                    value: engine.isScanning
                        ? "\(engine.completedCategories)/\(engine.totalCategories)"
                        : (engine.results.isEmpty ? "—" : L10n.string("smartcare.ready"))
                )
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                engine.runSmartCare()
            } label: {
                Label(
                    engine.isScanning ? L10n.string("smartcare.scanning") : L10n.string("smartcare.run"),
                    systemImage: "play.fill"
                )
                .frame(minWidth: 150)
            }
            .buttonStyle(SeaButtonStyle())
            .disabled(engine.isBusy)

            Button {
                engine.cleanSelected()
            } label: {
                Label(l10n: "smartcare.clean_selected", systemImage: "trash")
                    .frame(minWidth: 130)
            }
            .buttonStyle(AccentButtonStyle())
            .disabled(engine.isBusy || engine.reclaimableBytes == 0)

            if engine.isBusy {
                Button {
                    engine.stop()
                } label: {
                    Label(l10n: "smartcare.stop", systemImage: "stop.fill")
                        .frame(minWidth: 110)
                }
                .buttonStyle(GhostButtonStyle())

                ProgressView()
                    .controlSize(.small)
                    .tint(OCTheme.sea)
                Text(engine.progressLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(OCTheme.muted)
                    .animation(.easeOut(duration: 0.2), value: engine.progressLabel)
            }
        }
    }

    private var moduleGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 210), spacing: 12)],
            spacing: 12
        ) {
            ForEach(engine.results.filter { $0.totalBytes > 0 || $0.category.isCleanable }) { result in
                Button {
                    onOpenCategory(result.category)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: result.category.systemImage)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(OCTheme.sea)
                                .frame(width: 28, height: 28)
                                .background(OCTheme.sea.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Text(result.category.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(OCTheme.ink)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(OCTheme.faint)
                        }
                        Text(ByteFormat.string(result.totalBytes))
                            .font(.system(size: 26, weight: .semibold).monospacedDigit())
                            .foregroundStyle(result.totalBytes > 0 ? OCTheme.ink : OCTheme.faint)
                        Text(result.category.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(OCTheme.muted)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(L10n.format("smartcare.items_selected", Int64(result.items.count), ByteFormat.string(result.selectedBytes)))
                            .font(.system(size: 10))
                            .foregroundStyle(OCTheme.faint)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(OCTheme.glass.opacity(0.20))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            }
                            .shadow(color: OCTheme.shadow.opacity(0.4), radius: 8, x: 0, y: 3)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct CategoryDetailView: View {
    @Bindable var engine: ScanEngine
    let result: CategoryResult

    /// Live result from the engine when available (stays in sync after toggles / rescans).
    private var live: CategoryResult {
        engine.results.first(where: { $0.category == result.category }) ?? result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(live.category.title)
                        .font(.system(size: 24, weight: .bold))
                    Text(live.category.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(OCTheme.muted)
                }
                Spacer()
                if live.category.isCleanable {
                    Button(L10n.string("common.select_all")) {
                        engine.selectAll(in: live.category, selected: true)
                    }
                    .buttonStyle(GhostButtonStyle())
                    Button(L10n.string("common.select_none")) {
                        engine.selectAll(in: live.category, selected: false)
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            }
            .padding(22)
            .foregroundStyle(OCTheme.ink)

            List {
                ForEach(live.items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        if item.category.isCleanable {
                            Toggle("", isOn: Binding(
                                get: {
                                    engine.results
                                        .first(where: { $0.category == item.category })?
                                        .items.first(where: { $0.id == item.id })?
                                        .isSelected ?? item.isSelected
                                },
                                set: { _ in engine.toggleItem(item) }
                            ))
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.displayName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(OCTheme.ink)
                            Text(item.url.path)
                                .font(.system(size: 11))
                                .foregroundStyle(OCTheme.muted)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text(ByteFormat.string(item.byteCount))
                            .font(.system(size: 13).monospacedDigit())
                            .foregroundStyle(OCTheme.ink)
                    }
                    .padding(.vertical, 3)
                    .listRowBackground(OCTheme.card.opacity(0.85))
                }
            }
            .scrollContentBackground(.hidden)
        }
    }
}
