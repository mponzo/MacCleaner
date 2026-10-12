import SwiftUI

struct PerformanceView: View {
    @Bindable var performance: PerformanceEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if let metrics = performance.metrics {
                    metricsGrid(metrics)
                }
                maintenanceSection
                agentsSection
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

    private var agentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(l10n: "perf.agents")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(L10n.format("perf.agents.broken_count", Int64(performance.brokenAgentCount)))
                    .foregroundStyle(performance.brokenAgentCount > 0 ? OCTheme.accent : .secondary)
                Button(L10n.string("perf.agents.remove")) {
                    Task { await performance.removeSelectedAgents() }
                }
                .disabled(performance.selectedAgentBytes == 0 || performance.isRunningTask)
            }
            Text(l10n: "perf.agents.help")
                .font(.caption)
                .foregroundStyle(OCTheme.muted)

            ForEach(performance.launchAgents.prefix(40)) { agent in
                HStack(alignment: .top, spacing: 10) {
                    if agent.isUserDomain {
                        Toggle("", isOn: Binding(
                            get: { agent.isSelected },
                            set: { _ in performance.toggleAgent(agent.id) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                    } else {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(OCTheme.muted)
                            .frame(width: 18)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(agent.label).font(.body.weight(.medium))
                            if agent.isBroken {
                                Text(l10n: "common.broken")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(OCTheme.accent, in: Capsule())
                            }
                        }
                        Text(agent.url.path)
                            .font(.caption)
                            .foregroundStyle(OCTheme.muted)
                            .lineLimit(1)
                        if let exe = agent.executablePath {
                            Text(exe)
                                .font(.caption2)
                                .foregroundStyle(OCTheme.muted)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Text(agent.isUserDomain ? L10n.string("common.user") : L10n.string("common.system"))
                        .font(.caption2)
                        .foregroundStyle(OCTheme.muted)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(OCTheme.stroke))
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
