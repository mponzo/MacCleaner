import AppKit
import SwiftUI

struct RootView: View {
    @Bindable var engine: ScanEngine
    @Bindable var uninstaller: UninstallerEngine
    @Bindable var performance: PerformanceEngine
    @Bindable var privileged: PrivilegedHelperEngine
    @Bindable var updater: AppUpdateEngine
    @Bindable var preferences: AppPreferences
    @Bindable var duplicates: DuplicateFinderEngine
    @Bindable var similarPhotos: SimilarPhotosEngine
    @Bindable var scheduler: CleanupScheduler
    @Bindable var spaceExplorer: SpaceExplorerEngine
    @Bindable var orphanFinder: OrphanFinderEngine
    @Bindable var startup: StartupEngine
    @Bindable var developer: DeveloperCleanupEngine
    @Bindable var privacy: PrivacyHubEngine
    @State private var fda = FullDiskAccessManager.shared
    @State private var exclusions = CleanupExclusions.shared
    @State private var destination: SidebarDestination = .overview

    var body: some View {
        Group {
            if preferences.onboardingComplete {
                mainShell
            } else {
                OnboardingView(preferences: preferences, fda: fda)
            }
        }
        .preferredColorScheme(.dark)
        .tint(OCTheme.sea)
        .foregroundStyle(OCTheme.ink)
        .font(OCTheme.font(13))
        .frame(minWidth: 980, minHeight: 640)
        .id(preferences.languageRevision)
        .onAppear {
            preferences.finishLaunchSetup()
            fda.refresh()
        }
    }

    private var mainShell: some View {
        ZStack {
            OCScreenBackground()
            NavigationSplitView {
                sidebar
                    .navigationSplitViewColumnWidth(min: 210, ideal: 224, max: 270)
            } detail: {
                detail
            }
            .navigationTitle(L10n.string("app.name"))
        }
        .onReceive(NotificationCenter.default.publisher(for: .ocmmOpenSettings)) { _ in
            destination = .settings
        }
        .onReceive(NotificationCenter.default.publisher(for: .ocmmOpenPerformance)) { _ in
            destination = .performance
        }
        .onReceive(NotificationCenter.default.publisher(for: .ocmmUninstallAppFromService)) { note in
            guard let url = note.userInfo?["url"] as? URL else { return }
            destination = .applications
            Task { await uninstaller.prepareForServiceUninstall(bundleURL: url) }
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
                            .font(OCTheme.font(13, weight: .semibold))
                        Text(engine.isScanning ? engine.progressLabel : L10n.string("sidebar.overview.subtitle"))
                            .font(OCTheme.font(11))
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
                    .font(OCTheme.font(11, weight: .semibold))
                    .foregroundStyle(OCTheme.faint)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Section {
                sidebarItem("sidebar.applications", icon: "app.badge.checkmark", tag: .applications)
                sidebarItem("sidebar.orphans", icon: "doc.text.magnifyingglass", tag: .orphans)
                sidebarItem("sidebar.duplicates", icon: "doc.on.doc", tag: .duplicates)
                sidebarItem("sidebar.similar_photos", icon: "photo.on.rectangle.angled", tag: .similarPhotos)
                sidebarItem("sidebar.performance", icon: "gauge.with.dots.needle.67percent", tag: .performance)
                sidebarItem("sidebar.startup", icon: "power", tag: .startup)
                sidebarItem("sidebar.developer", icon: "hammer", tag: .developer)
                sidebarItem("sidebar.space_lens", icon: "externaldrive.fill.badge.magnifyingglass", tag: .spaceLens)
                sidebarItem("sidebar.privacy", icon: "hand.raised", tag: .privacy)
            } header: {
                Text(l10n: "sidebar.tools")
                    .font(OCTheme.font(11, weight: .semibold))
                    .foregroundStyle(OCTheme.faint)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Section {
                sidebarItem("sidebar.scheduler", icon: "clock.arrow.circlepath", tag: .scheduler)
                sidebarItem("sidebar.updates", icon: "arrow.down.app", tag: .updates)
                sidebarItem("sidebar.privileged", icon: "lock.shield", tag: .privileged)
                sidebarItem("sidebar.settings", icon: "gearshape", tag: .settings)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 10) {
                OCBrandIcon().frame(width: 34, height: 34)
                Text("MacCleaner").font(OCTheme.font(17, weight: .semibold))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 22)
        }
        .safeAreaInset(edge: .bottom) {
            Label(L10n.string("overview.local"), systemImage: "lock.shield")
                .font(OCTheme.font(11)).foregroundStyle(OCTheme.muted)
                .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(OCTheme.sidebarFill.opacity(0.65))
        .foregroundStyle(OCTheme.ink)
    }

    private func sidebarItem(_ key: String, icon: String, tag: SidebarDestination) -> some View {
        Label {
            Text(L10n.string(key: key))
                .font(OCTheme.font(13, weight: .medium))
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
            SmartCareView(engine: engine, fda: fda) { category in
                destination = .category(category)
            }
        case .applications:
            ApplicationsView(uninstaller: uninstaller)
        case .orphans:
            OrphanFinderView(engine: orphanFinder)
        case .performance:
            PerformanceView(performance: performance) {
                destination = .startup
            }
        case .startup:
            StartupView(engine: startup)
        case .developer:
            DeveloperCleanupView(engine: developer)
        case .privileged:
            PrivilegedHelperView(privileged: privileged)
        case .spaceLens:
            SpaceExplorerView(explorer: spaceExplorer, engine: engine)
        case .privacy:
            PrivacyHubView(engine: privacy, fda: fda)
        case .duplicates:
            DuplicateFinderView(engine: duplicates)
        case .similarPhotos:
            SimilarPhotosView(engine: similarPhotos)
        case .scheduler:
            SchedulerView(scheduler: scheduler)
        case .updates:
            UpdatesView(updater: updater, preferences: preferences)
        case .settings:
            SettingsView(preferences: preferences, fda: fda, exclusions: exclusions)
        case .category(let category):
            if let result = engine.results.first(where: { $0.category == category }) {
                CategoryDetailView(engine: engine, result: result, exclusions: exclusions)
            } else {
                ContentUnavailableView(L10n.string("smartcare.run_prompt"), systemImage: "sparkles")
            }
        }
    }
}

struct SmartCareView: View {
    @Bindable var engine: ScanEngine
    @Bindable var fda: FullDiskAccessManager
    var onOpenCategory: (ScanCategory) -> Void = { _ in }
    @State private var showReview = false
    @State private var showEmpty = false

    private var cleanable: [CategoryResult] {
        engine.results.filter { $0.category.isCleanable }
    }
    private var availableBytes: Int64 { cleanable.reduce(0) { $0 + $1.totalBytes } }
    private var isBeforeScan: Bool { engine.results.isEmpty && !engine.isBusy }
    private var selectedCount: Int { cleanable.flatMap(\.items).filter(\.isSelected).count }
    private func label(_ key: String) -> String { L10n.string(key: "overview." + key) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(label("vision_title")).font(OCTheme.font(34, weight: .semibold)).tracking(-1)
                            Text(engine.results.isEmpty ? label("intro") : engine.progressLabel)
                                .font(OCTheme.font(13)).foregroundStyle(OCTheme.muted)
                        }
                        Spacer()
                        if !isBeforeScan {
                            Button(engine.results.isEmpty ? label("scan") : label("rescan")) {
                                engine.runSmartCare()
                            }
                            .buttonStyle(SeaButtonStyle()).disabled(engine.isBusy)
                        }
                    }
                    if isBeforeScan { welcome } else { summary }
                    if !fda.hasFullDiskAccess { fdaBanner }
                    if engine.isBusy {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(engine.progressLabel).font(OCTheme.font(13))
                                Spacer()
                                Button(L10n.string("smartcare.stop")) { engine.stop() }
                                    .buttonStyle(GhostButtonStyle())
                            }
                            if engine.isScanning {
                                ProgressView(value: engine.scanProgress)
                            } else {
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                    if !engine.results.isEmpty { categoryList }
                    if let clean = engine.lastCleanResult {
                        Text(L10n.format("smartcare.last_clean", clean.movedCount, ByteFormat.string(clean.freedBytes)))
                            .foregroundStyle(OCTheme.muted)
                    }
                    if let error = engine.errorMessage {
                        Text(error).foregroundStyle(OCTheme.danger).textSelection(.enabled)
                    }
                    Label(label("reassurance"), systemImage: "lock.shield")
                        .font(OCTheme.font(12)).foregroundStyle(OCTheme.muted)
                }
                .padding(32)
                .frame(maxWidth: 1100, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            if !engine.results.isEmpty { footer }
        }
        .font(OCTheme.font(13))
        .sheet(isPresented: $showReview) { review }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .top, spacing: 24) {
                OCBrandIcon().frame(width: 88, height: 88)
                VStack(alignment: .leading, spacing: 12) {
                    Text(label("welcome_title")).font(OCTheme.font(24, weight: .semibold))
                    Text(label("welcome_body"))
                        .font(OCTheme.font(13)).foregroundStyle(OCTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { engine.runSmartCare() } label: {
                        Label(label("scan"), systemImage: "viewfinder")
                    }
                    .buttonStyle(SeaButtonStyle()).padding(.top, 8)
                }
                Spacer(minLength: 0)
            }
            Divider().overlay(OCTheme.stroke)
            VStack(alignment: .leading, spacing: 20) {
                welcomeRow("externaldrive", title: "welcome_cache", body: "welcome_cache_body")
                welcomeRow("hammer", title: "welcome_dev", body: "welcome_dev_body")
                welcomeRow("doc.on.doc", title: "welcome_files", body: "welcome_files_body")
            }
            Label(label("welcome_control"), systemImage: "checkmark.shield")
                .font(OCTheme.font(12)).foregroundStyle(OCTheme.muted)
                .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OCTheme.canvasElevated, in: RoundedRectangle(cornerRadius: 16))
    }

    private func welcomeRow(_ icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 18))
                .foregroundStyle(OCTheme.sea).frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(label(title)).font(OCTheme.font(13, weight: .semibold))
                Text(label(body)).font(OCTheme.font(12)).foregroundStyle(OCTheme.muted)
            }
        }
    }

    private var summary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 34) {
                spaceMetrics.frame(width: 230, alignment: .leading)
                Rectangle().fill(OCTheme.stroke).frame(width: 1)
                HomeSpaceMap(results: cleanable, onOpenCategory: onOpenCategory)
                    .frame(minWidth: 300, maxWidth: .infinity)
            }
            VStack(alignment: .leading, spacing: 28) {
                spaceMetrics
                HomeSpaceMap(results: cleanable, onOpenCategory: onOpenCategory)
            }
        }
        .padding(.vertical, 26)
        .overlay(alignment: .top) { Divider().overlay(OCTheme.stroke) }
        .overlay(alignment: .bottom) { Divider().overlay(OCTheme.stroke) }
    }

    private var spaceMetrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label("available")).font(OCTheme.font(13)).foregroundStyle(OCTheme.muted)
            Text(engine.results.isEmpty ? "—" : ByteFormat.string(availableBytes))
                .font(OCTheme.font(40, weight: .semibold)).monospacedDigit()
                .foregroundStyle(OCTheme.sea).tracking(-1)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(engine.results.isEmpty ? label("awaiting_scan") : L10n.format("overview.analyzed", ByteFormat.string(engine.scannedBytes)))
                .font(OCTheme.font(12)).foregroundStyle(OCTheme.muted)
            HStack(spacing: 7) {
                Circle().fill(engine.isBusy ? OCTheme.accent : OCTheme.sea).frame(width: 5, height: 5)
                Text(engine.isBusy ? engine.progressLabel : label("local"))
                    .font(OCTheme.font(11)).foregroundStyle(OCTheme.muted)
            }.padding(.top, 12)
        }
    }

    private var categoryList: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label("review")).font(OCTheme.font(17, weight: .semibold))
                Spacer()
                Button(selectedCount > 0 ? L10n.string("common.select_none") : L10n.string("common.select_all")) {
                    let select = selectedCount == 0
                    for result in cleanable { engine.selectAll(in: result.category, selected: select) }
                }
                .buttonStyle(.plain).foregroundStyle(OCTheme.sea).disabled(engine.isBusy)
            }.padding(.bottom, 18)
            Divider().overlay(OCTheme.stroke)
            ForEach(engine.results.filter { $0.totalBytes > 0 }) { result in categoryRow(result) }
            let empty = engine.results.filter { $0.totalBytes == 0 }
            if !empty.isEmpty {
                DisclosureGroup(isExpanded: $showEmpty) {
                    ForEach(empty) { result in categoryRow(result) }
                } label: {
                    Text(L10n.format("overview.empty_categories", empty.count))
                        .font(OCTheme.font(12)).foregroundStyle(OCTheme.muted)
                }.padding(.top, 18)
            }
        }
    }

    private func categoryRow(_ result: CategoryResult) -> some View {
        HStack(spacing: 14) {
            if result.category.isCleanable {
                Toggle(result.category.title, isOn: Binding(
                    get: { !result.items.isEmpty && result.items.allSatisfy(\.isSelected) },
                    set: { engine.selectAll(in: result.category, selected: $0) }
                ))
                .labelsHidden().toggleStyle(.checkbox)
                .disabled(engine.isBusy || result.items.isEmpty)
                .help(result.selectedBytes > 0 ? label("partial") : result.category.title)
            } else {
                Image(systemName: "info.circle").foregroundStyle(OCTheme.muted).frame(width: 16)
            }
            Image(systemName: result.category.systemImage)
                .font(OCTheme.font(18)).foregroundStyle(OCTheme.sea)
                .frame(width: 36, height: 36)
                .background(OCTheme.sea.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            Button { onOpenCategory(result.category) } label: {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(result.category.title).font(OCTheme.font(13, weight: .semibold))
                            .foregroundStyle(OCTheme.ink)
                        Text(result.category.detail).font(OCTheme.font(12))
                            .foregroundStyle(OCTheme.muted).lineLimit(2)
                        if result.selectedBytes > 0 && !result.items.allSatisfy(\.isSelected) {
                            Text(L10n.format("smartcare.items_selected", Int64(result.items.filter(\.isSelected).count), ByteFormat.string(result.selectedBytes)))
                                .font(OCTheme.font(11)).foregroundStyle(OCTheme.sea)
                        }
                    }
                    Spacer(minLength: 12)
                    Text(ByteFormat.string(result.totalBytes))
                        .font(OCTheme.font(14, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(OCTheme.ink)
                    Image(systemName: "chevron.right").font(OCTheme.font(11))
                        .foregroundStyle(OCTheme.muted)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 17).padding(.horizontal, 8)
        .overlay(alignment: .bottom) { Divider().overlay(OCTheme.stroke) }
    }

    private var footer: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text(ByteFormat.string(engine.reclaimableBytes) + " " + label("selected"))
                    .font(OCTheme.font(16, weight: .semibold)).monospacedDigit()
                Text(L10n.format("overview.selected_items", selectedCount))
                    .font(OCTheme.font(12)).foregroundStyle(OCTheme.muted)
            }
            Spacer()
            Button(label("review_clean")) { showReview = true }
                .buttonStyle(SeaButtonStyle())
                .disabled(engine.isBusy || engine.reclaimableBytes == 0)
        }
        .padding(.horizontal, 32).padding(.vertical, 20)
        .background(OCTheme.canvasElevated)
        .overlay(alignment: .top) { Divider().overlay(OCTheme.stroke) }
    }

    private var review: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(label("review_clean")).font(OCTheme.font(22, weight: .semibold))
            Text(label("confirm_body")).foregroundStyle(OCTheme.muted)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(cleanable.filter { $0.selectedBytes > 0 }) { result in
                        Text(result.category.title).font(OCTheme.font(14, weight: .semibold))
                        ForEach(result.items.filter(\.isSelected)) { item in
                            HStack(alignment: .top) {
                                Text(item.url.path).textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(ByteFormat.string(item.byteCount)).monospacedDigit()
                            }.font(OCTheme.font(12)).foregroundStyle(OCTheme.muted)
                        }
                    }
                }
            }.frame(maxHeight: 320)
            HStack {
                Text(ByteFormat.string(engine.reclaimableBytes)).font(OCTheme.font(16, weight: .semibold))
                Spacer()
                Button(label("back")) { showReview = false }.keyboardShortcut(.cancelAction)
                Button(label("trash")) {
                    showReview = false
                    engine.cleanSelected()
                }.buttonStyle(SeaButtonStyle()).disabled(engine.isBusy || selectedCount == 0)
            }
        }
        .font(OCTheme.font(13)).padding(28).frame(width: 640)
        .background(OCTheme.canvas).preferredColorScheme(.dark)
    }

    private var fdaBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield")
                .font(OCTheme.font(18, weight: .semibold))
                .foregroundStyle(OCTheme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n: "fda.banner.title")
                    .font(OCTheme.font(14, weight: .semibold))
                Text(l10n: "fda.banner.body")
                    .font(OCTheme.font(12))
                    .foregroundStyle(OCTheme.muted)
            }
            Spacer(minLength: 8)
            Button(L10n.string("fda.banner.action")) {
                fda.openSystemSettings()
                fda.startWatching {
                    fda.refresh()
                }
            }
            .buttonStyle(SeaButtonStyle())
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(OCTheme.accent.opacity(0.14))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(OCTheme.accent.opacity(0.4), lineWidth: 1)
                }
        }
    }

}

struct CategoryDetailView: View {
    @Bindable var engine: ScanEngine
    let result: CategoryResult
    @Bindable var exclusions: CleanupExclusions

    /// Live result from the engine when available (stays in sync after toggles / rescans).
    private var live: CategoryResult {
        engine.results.first(where: { $0.category == result.category }) ?? result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(live.category.title)
                        .font(OCTheme.font(24, weight: .bold))
                    Text(live.category.detail)
                        .font(OCTheme.font(13))
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
                                .font(OCTheme.font(13, weight: .medium))
                                .foregroundStyle(OCTheme.ink)
                            Text(item.url.path)
                                .font(OCTheme.font(11))
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
                    .contextMenu {
                        Button(L10n.string("excl.always")) {
                            exclusions.add(item.url)
                            removeFromResults(item)
                        }
                        Button(L10n.string("settings.reveal")) {
                            NSWorkspace.shared.activateFileViewerSelecting([item.url])
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func removeFromResults(_ item: ScanItem) {
        guard let cIdx = engine.results.firstIndex(where: { $0.category == item.category }) else { return }
        engine.results[cIdx].items.removeAll { $0.id == item.id }
    }
}
