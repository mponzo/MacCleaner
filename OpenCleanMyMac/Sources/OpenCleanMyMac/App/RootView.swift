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
    @State private var fda = FullDiskAccessManager.shared
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
                sidebarItem("sidebar.duplicates", icon: "doc.on.doc", tag: .duplicates)
                sidebarItem("sidebar.similar_photos", icon: "photo.on.rectangle.angled", tag: .similarPhotos)
                sidebarItem("sidebar.performance", icon: "gauge.with.dots.needle.67percent", tag: .performance)
                sidebarItem("sidebar.space_lens", icon: "chart.bar.fill", tag: .spaceLens)
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
        case .performance:
            PerformanceView(performance: performance)
        case .privileged:
            PrivilegedHelperView(privileged: privileged)
        case .spaceLens:
            SpaceLensView(engine: engine)
        case .duplicates:
            DuplicateFinderView(engine: duplicates)
        case .similarPhotos:
            SimilarPhotosView(engine: similarPhotos)
        case .scheduler:
            SchedulerView(scheduler: scheduler)
        case .updates:
            UpdatesView(updater: updater, preferences: preferences)
        case .settings:
            SettingsView(preferences: preferences, fda: fda)
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
    @Bindable var fda: FullDiskAccessManager
    var onOpenCategory: (ScanCategory) -> Void = { _ in }
    @State private var showReview = false
    @State private var showEmpty = false

    private var cleanable: [CategoryResult] {
        engine.results.filter { $0.category.isCleanable }
    }
    private var availableBytes: Int64 { cleanable.reduce(0) { $0 + $1.totalBytes } }
    private var selectedCount: Int { cleanable.flatMap(\.items).filter(\.isSelected).count }
    private func label(_ key: String) -> String { L10n.string(key: "overview." + key) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(label("title")).font(OCTheme.font(28, weight: .semibold))
                            Text(engine.results.isEmpty ? label("intro") : engine.progressLabel)
                                .font(OCTheme.font(13)).foregroundStyle(OCTheme.muted)
                        }
                        Spacer()
                        Button(engine.results.isEmpty ? label("scan") : label("rescan")) {
                            engine.runSmartCare()
                        }
                        .buttonStyle(GhostButtonStyle()).disabled(engine.isBusy)
                    }
                    summary
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
            footer
        }
        .font(OCTheme.font(13))
        .sheet(isPresented: $showReview) { review }
    }

    private var summary: some View {
        HStack(alignment: .center, spacing: 36) {
            VStack(alignment: .leading, spacing: 8) {
                Text(ByteFormat.string(availableBytes))
                    .font(OCTheme.font(42, weight: .semibold)).monospacedDigit()
                Text(label("available")).foregroundStyle(OCTheme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Text(ByteFormat.string(engine.scannedBytes))
                    .font(OCTheme.font(20, weight: .semibold)).monospacedDigit()
                Text(L10n.string("smartcare.scanned")).foregroundStyle(OCTheme.muted)
                if !engine.results.isEmpty {
                    Text("\(engine.completedCategories)/\(engine.totalCategories) " + label("categories"))
                        .font(OCTheme.font(12)).foregroundStyle(OCTheme.muted)
                }
            }
        }
        .padding(26).frame(maxWidth: .infinity, alignment: .leading)
        .background(OCTheme.canvasElevated, in: RoundedRectangle(cornerRadius: 12))
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
                }
            }
            .scrollContentBackground(.hidden)
        }
    }
}
