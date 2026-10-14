import AppKit
import SwiftUI

struct PerformanceView: View {
    @Bindable var performance: PerformanceEngine
    var onOpenStartup: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if let metrics = performance.metrics {
                    metricsGrid(metrics)
                }
                monitorActions
                startupLink
                maintenanceSection
                processesSection
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

    private func metricsGrid(_ m: SystemMetrics) -> some View {
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

    private var processesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n: "perf.top_processes")
                .font(.title3.weight(.semibold))
            ForEach(performance.processes) { proc in
                HStack {
                    Text(proc.name)
                        .lineLimit(1)
                    Spacer()
                    Text(L10n.format("perf.pid", proc.pid))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(OCTheme.muted)
                        .frame(width: 80, alignment: .trailing)
                    Text(ByteFormat.string(Int64(proc.memoryBytes)))
                        .font(.body.monospacedDigit())
                        .frame(width: 90, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(OCTheme.stroke))
    }
}
