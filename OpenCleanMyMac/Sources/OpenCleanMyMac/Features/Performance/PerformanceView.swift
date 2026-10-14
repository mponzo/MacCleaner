import AppKit
import SwiftUI

struct PerformanceView: View {
    @Bindable var performance: PerformanceEngine
    var onOpenStartup: () -> Void = {}
    @State private var expandedGroups: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                systemMonitorCard
                if let metrics = performance.metrics {
                    metricsSection(metrics)
                }
                monitorActions
                startupLink
                maintenanceSection
                if let result = performance.lastTaskResult {
                    Text(result.message)
                        .font(.callout)
                        .foregroundStyle(result.success ? OCTheme.sea : Color(red: 1, green: 0.45, blue: 0.45))
                }
                if let clean = performance.lastCleanResult {
                    Text(L10n.format("perf.removed_agents", Int64(clean.movedCount), ByteFormat.string(clean.freedBytes)))
                        .font(.callout)
                        .foregroundStyle(OCTheme.muted)
                }
                if let error = performance.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }
            .padding(28)
        }
        .task {
            performance.startPolling()
            if performance.launchAgents.isEmpty {
                await performance.refreshAll()
            }
        }
        .onDisappear {
            performance.stopPolling()
        }
        .onChange(of: performance.showAllProcesses) { _, _ in
            Task { await performance.refreshLive() }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            OCPageHeader(
                title: L10n.string("perf.title"),
                subtitle: L10n.string("perf.subtitle")
            )
            Spacer()
            Button {
                Task { await performance.refreshAll() }
            } label: {
                Label(l10n: "common.refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(GhostButtonStyle())
            .disabled(performance.isRefreshing || performance.isRunningTask)
        }
    }

    private var systemMonitorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    performance.processesExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .foregroundStyle(OCTheme.sea)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n: "perf.monitor.title")
                            .font(OCTheme.font(15, weight: .semibold))
                            .foregroundStyle(OCTheme.ink)
                        Text(l10n: "perf.monitor.help")
                            .font(OCTheme.font(11))
                            .foregroundStyle(OCTheme.muted)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: performance.processesExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(OCTheme.muted)
                }
            }
            .buttonStyle(.plain)

            if performance.processesExpanded {
                processControls
                if performance.processes.isEmpty {
                    Text(l10n: "perf.monitor.empty")
                        .font(OCTheme.font(12))
                        .foregroundStyle(OCTheme.muted)
                        .padding(.vertical, 8)
                } else if performance.processGroups.isEmpty {
                    Text(l10n: "perf.monitor.no_match")
                        .font(OCTheme.font(12))
                        .foregroundStyle(OCTheme.muted)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(performance.processGroups) { group in
                            processGroupRow(group)
                        }
                    }
                }
                Text(l10n: "perf.monitor.system_note")
                    .font(OCTheme.font(11))
                    .foregroundStyle(OCTheme.faint)
            }
        }
        .padding(16)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(OCTheme.stroke))
    }

    private var processControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField(L10n.string("perf.monitor.search"), text: $performance.processQuery)
                    .textFieldStyle(.roundedBorder)
                if !performance.processQuery.isEmpty {
                    Button(L10n.string("perf.monitor.clear_search")) {
                        performance.processQuery = ""
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            }
            HStack(spacing: 12) {
                Picker(L10n.string("perf.monitor.sort_by"), selection: $performance.sortKey) {
                    ForEach(ProcessSortKey.allCases) { key in
                        Text(key.title).tag(key)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 160)

                Toggle(L10n.string("perf.monitor.sort_asc"), isOn: $performance.sortAscending)
                    .toggleStyle(.checkbox)

                Toggle(L10n.string("perf.monitor.show_all"), isOn: $performance.showAllProcesses)
                    .toggleStyle(.checkbox)

                Spacer()
                Text(L10n.format("perf.processes", Int64(performance.metrics?.processCount ?? performance.processes.count)))
                    .font(OCTheme.font(11))
                    .foregroundStyle(OCTheme.muted)
            }
            .font(OCTheme.font(12))
        }
    }

    private func processGroupRow(_ group: ProcessGroup) -> some View {
        let expanded = expandedGroups.contains(group.id)
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                if !group.helpers.isEmpty {
                    Button {
                        if expanded {
                            expandedGroups.remove(group.id)
                        } else {
                            expandedGroups.insert(group.id)
                        }
                    } label: {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(OCTheme.muted)
                            .frame(width: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 12)
                }

                ProcessIcon(bundleURL: group.primary.bundleURL, name: group.primary.name)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.primary.name)
                        .font(OCTheme.font(13, weight: .medium))
                        .lineLimit(1)
                    if !group.helpers.isEmpty {
                        Text(L10n.format("perf.monitor.helpers", Int64(group.helpers.count)))
                            .font(OCTheme.font(10))
                            .foregroundStyle(OCTheme.muted)
                    } else {
                        Text(L10n.format("perf.pid", group.primary.pid))
                            .font(OCTheme.font(10).monospacedDigit())
                            .foregroundStyle(OCTheme.muted)
                    }
                }
                Spacer(minLength: 8)
                Text(String(format: "%.1f%%", group.totalCPUPercent))
                    .font(OCTheme.font(12).monospacedDigit())
                    .foregroundStyle(group.totalCPUPercent > 50 ? OCTheme.accent : OCTheme.ink)
                    .frame(width: 58, alignment: .trailing)
                Text(ByteFormat.string(Int64(group.totalMemoryBytes)))
                    .font(OCTheme.font(12).monospacedDigit())
                    .frame(width: 72, alignment: .trailing)
            }
            .padding(.vertical, 8)

            if expanded {
                ForEach(group.helpers) { helper in
                    HStack(spacing: 10) {
                        Color.clear.frame(width: 12)
                        ProcessIcon(bundleURL: helper.bundleURL, name: helper.name)
                            .frame(width: 22, height: 22)
                            .opacity(0.85)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(helper.name)
                                .font(OCTheme.font(12))
                                .lineLimit(1)
                            Text(L10n.format("perf.pid", helper.pid))
                                .font(OCTheme.font(10).monospacedDigit())
                                .foregroundStyle(OCTheme.muted)
                        }
                        Spacer()
                        Text(String(format: "%.1f%%", helper.cpuPercent))
                            .font(OCTheme.font(11).monospacedDigit())
                            .frame(width: 58, alignment: .trailing)
                        Text(ByteFormat.string(Int64(helper.memoryBytes)))
                            .font(OCTheme.font(11).monospacedDigit())
                            .frame(width: 72, alignment: .trailing)
                    }
                    .padding(.vertical, 5)
                    .padding(.leading, 16)
                }
            }

            Divider().overlay(OCTheme.stroke.opacity(0.5))
        }
    }

    private func metricsSection(_ m: SystemMetrics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    performance.metricsExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(l10n: "perf.monitor.cpu_memory")
                        .font(OCTheme.font(13, weight: .semibold))
                    Spacer()
                    Image(systemName: performance.metricsExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(OCTheme.muted)
                }
            }
            .buttonStyle(.plain)

            if performance.metricsExpanded {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    metricCard(
                        L10n.string("perf.memory"),
                        L10n.format("perf.memory_used", Int64(m.memoryUsedPercent)),
                        ByteFormat.string(Int64(m.usedMemoryBytes))
                    )
                    metricCard(
                        L10n.string("perf.pressure"),
                        String(format: "%.0f%%", m.memoryPressurePercent),
                        L10n.format("perf.compressed", ByteFormat.string(Int64(m.compressedMemoryBytes)))
                    )
                    metricCard(
                        L10n.string("perf.free_ram"),
                        ByteFormat.string(Int64(m.freeMemoryBytes)),
                        L10n.format("perf.wired", ByteFormat.string(Int64(m.wiredMemoryBytes)))
                    )
                    metricCard(
                        L10n.string("perf.cpu"),
                        String(format: "%.0f%%", m.cpuLoadPercent),
                        L10n.format("perf.processes", Int64(m.processCount))
                    )
                    metricCard(
                        L10n.string("perf.disk_free"),
                        ByteFormat.string(m.diskFreeBytes),
                        String(format: L10n.string("perf.disk_used"), m.diskUsedPercent)
                    )
                    metricCard(
                        L10n.string("perf.uptime"),
                        m.uptimeLabel,
                        L10n.string("perf.uptime.detail")
                    )
                }
            }
        }
    }

    private var monitorActions: some View {
        HStack(spacing: 10) {
            Button {
                openActivityMonitor()
            } label: {
                Label(l10n: "perf.open_activity_monitor", systemImage: "gauge.with.dots.needle.67percent")
            }
            .buttonStyle(SeaButtonStyle())

            Text(l10n: "perf.activity_monitor.help")
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.muted)
            Spacer()
        }
    }

    private func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        } else if let fallback = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
            NSWorkspace.shared.open(fallback)
        }
    }

    private func metricCard(_ title: String, _ value: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(OCTheme.muted)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(OCTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(OCTheme.stroke, lineWidth: 1))
        .shadow(color: OCTheme.shadow.opacity(0.3), radius: 6, x: 0, y: 2)
    }

    private var startupLink: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "power")
                .foregroundStyle(OCTheme.sea)
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n: "perf.startup_link.title")
                    .font(OCTheme.font(14, weight: .semibold))
                Text(l10n: "perf.startup_link.body")
                    .font(OCTheme.font(12))
                    .foregroundStyle(OCTheme.muted)
            }
            Spacer()
            Button(L10n.string("perf.startup_link.open")) {
                onOpenStartup()
            }
            .buttonStyle(SeaButtonStyle())
        }
        .padding(14)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(OCTheme.stroke))
    }

    private var maintenanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n: "perf.maintenance")
                .font(.title3.weight(.semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(MaintenanceTaskID.allCases) { task in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: task.systemImage)
                                .foregroundStyle(OCTheme.sea)
                            Text(task.title).font(.headline)
                            Spacer()
                            if task.needsAdmin {
                                Text(l10n: "common.admin")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(OCTheme.accent.opacity(0.15), in: Capsule())
                                    .foregroundStyle(OCTheme.accent)
                            }
                        }
                        Text(task.detail)
                            .font(.caption)
                            .foregroundStyle(OCTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            Task { await performance.runMaintenance(task) }
                        } label: {
                            Text(l10n: "common.run")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SeaButtonStyle())
                        .disabled(performance.isRunningTask)
                    }
                    .padding(14)
                    .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(OCTheme.stroke))
                }
            }
        }
    }
}

private struct ProcessIcon: View {
    let bundleURL: URL?
    let name: String

    var body: some View {
        Group {
            if let bundleURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: bundleURL.path))
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app.fill")
                    .foregroundStyle(OCTheme.sea.opacity(0.8))
            }
        }
        .aspectRatio(contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityLabel(name)
    }
}
