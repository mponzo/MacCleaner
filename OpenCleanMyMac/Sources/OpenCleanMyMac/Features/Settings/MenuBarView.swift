import AppKit
import IOKit.ps
import SwiftUI

struct MenuBarView: View {
    @Bindable var preferences: AppPreferences
    @Bindable var engine: ScanEngine
    @Bindable var performance: PerformanceEngine
    @Environment(\.openWindow) private var openWindow

    @State private var network = NetworkRates(
        uploadBytesPerSec: 0,
        downloadBytesPerSec: 0,
        interfaceName: "en0",
        ssid: nil,
        isSatisfied: true
    )

    private var metrics: SystemMetrics {
        performance.metrics ?? MetricsCollector.snapshot()
    }

    private var hostName: String {
        Host.current().localizedName ?? "Mac"
    }

    private var statusIsGood: Bool {
        metrics.diskUsedPercent < 90 && metrics.memoryUsedPercent < 90
    }

    private var uptimeText: String {
        let seconds = Int(ProcessInfo.processInfo.systemUptime)
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 {
            return L10n.format("menubar.uptime_days", Int64(days), Int64(hours))
        }
        return L10n.format("menubar.uptime_hours", Int64(hours), Int64(minutes))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                header
                protectionStrip
                statsGrid
                secondaryGrid
                tipCard
            }
            .padding(14)

            footer
        }
        .frame(width: 380)
        .frame(minHeight: 720, idealHeight: 760, maxHeight: 860)
        .fixedSize(horizontal: true, vertical: false)
        .background { menuGlassBackground }
        .background(MenuBarWindowChrome())
        .preferredColorScheme(.dark)
        .foregroundStyle(OCTheme.ink)
        .id(preferences.languageRevision)
        .onReceive(NotificationCenter.default.publisher(for: .ocmmReopenMainWindow)) { _ in
            openMainWindow()
        }
        .task {
            performance.startPolling()
            if performance.metrics == nil {
                await performance.refreshLive()
            }
            if performance.launchAgents.isEmpty {
                await performance.refreshAll()
            }
            while !Task.isCancelled {
                network = await NetworkStatus.sampleRates(interval: 1.2)
            }
        }
    }

    private var menuGlassBackground: some View {
        ZStack {
            OCGlassMaterial(material: .hudWindow, blending: .behindWindow)
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.28, blue: 0.55).opacity(0.78),
                    Color(red: 0.04, green: 0.10, blue: 0.24).opacity(0.90),
                    Color(red: 0.08, green: 0.18, blue: 0.38).opacity(0.84)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(l10n: "menubar.status_label")
                        .font(.system(size: 18, weight: .bold))
                    Text(statusIsGood ? L10n.string("menubar.status.good") : L10n.string("menubar.status.attention"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(statusIsGood ? OCTheme.sea : OCTheme.accent)
                }
                Text(hostName)
                    .font(.system(size: 12))
                    .foregroundStyle(OCTheme.muted)
            }
            Spacer(minLength: 0)
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [OCTheme.sea.opacity(0.65), OCTheme.glass.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .shadow(color: OCTheme.sea.opacity(0.40), radius: 10, x: 0, y: 2)
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }

    private var protectionStrip: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(OCTheme.success)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(l10n: "menubar.ready_title")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(l10n: "menubar.ready_badge")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(OCTheme.success)
                }
                Text(L10n.format("menubar.ready_detail", uptimeText))
                    .font(.system(size: 11))
                    .foregroundStyle(OCTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background { tileBackground(corner: 14) }
    }

    private var statsGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            glassTile(icon: "internaldrive.fill", title: L10n.string("menubar.storage")) {
                Text(L10n.format("menubar.available", ByteFormat.string(metrics.diskFreeBytes)))
                    .font(.system(size: 12, weight: .medium))
                Text(L10n.format("menubar.disk_used", Int64(metrics.diskUsedPercent.rounded())))
                    .font(.system(size: 11))
                    .foregroundStyle(OCTheme.muted)
                Button(L10n.string("menubar.free_up")) {
                    openMainWindow()
                    DispatchQueue.main.async {
                        Task { await engine.runSmartCare() }
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(OCTheme.sea)
                .padding(.top, 2)
            }

            glassTile(icon: "memorychip.fill", title: L10n.string("menubar.memory")) {
                Text(L10n.format("menubar.pressure", Int64(metrics.memoryUsedPercent.rounded())))
                    .font(.system(size: 12, weight: .medium))
                Text(ByteFormat.string(Int64(metrics.freeMemoryBytes)) + " " + L10n.string("menubar.free_short"))
                    .font(.system(size: 11))
                    .foregroundStyle(OCTheme.muted)
                Button(L10n.string("menubar.free_up")) {
                    openMainWindow(then: .ocmmOpenPerformance)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(OCTheme.sea)
                .padding(.top, 2)
            }

            glassTile(icon: "battery.100", title: L10n.string("menubar.battery")) {
                let battery = BatteryStatus.current()
                if let percent = battery.percent {
                    Text(L10n.format("menubar.battery_value", Int64(percent)))
                        .font(.system(size: 18, weight: .semibold).monospacedDigit())
                        .foregroundStyle(percent < 20 ? OCTheme.accent : OCTheme.ink)
                    Text(batteryDetail(battery))
                        .font(.system(size: 11))
                        .foregroundStyle(OCTheme.muted)
                } else {
                    Text(l10n: "menubar.battery_unavailable")
                        .font(.system(size: 11))
                        .foregroundStyle(OCTheme.muted)
                }
            }

            glassTile(icon: "cpu", title: L10n.string("menubar.cpu")) {
                Text(L10n.format("menubar.cpu_usage", Int64(metrics.cpuLoadPercent.rounded())))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(metrics.cpuLoadPercent > 70 ? OCTheme.accent : OCTheme.ink)
                Text(L10n.format("menubar.processes", Int64(max(performance.processes.count, metrics.processCount))))
                    .font(.system(size: 11))
                    .foregroundStyle(OCTheme.muted)
                Text(L10n.format("menubar.agents_brief", Int64(performance.brokenAgentCount)))
                    .font(.system(size: 11))
                    .foregroundStyle(performance.brokenAgentCount > 0 ? OCTheme.accent : OCTheme.muted)
            }
        }
    }

    private var secondaryGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            glassTile(icon: "wifi", title: networkTitle) {
                HStack(spacing: 10) {
                    Label(NetworkStatus.formatRate(network.uploadBytesPerSec), systemImage: "arrow.up")
                    Label(NetworkStatus.formatRate(network.downloadBytesPerSec), systemImage: "arrow.down")
                }
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(OCTheme.ink)
                Text(network.isSatisfied ? L10n.string("menubar.network_online") : L10n.string("menubar.network_offline"))
                    .font(.system(size: 11))
                    .foregroundStyle(network.isSatisfied ? OCTheme.success : OCTheme.danger)
                Button(L10n.string("menubar.network_settings")) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(OCTheme.sea)
                .padding(.top, 2)
            }

            glassTile(icon: "laptopcomputer.and.iphone", title: L10n.string("menubar.activity")) {
                let tops = Array(performance.processes.prefix(2))
                if tops.isEmpty {
                    Text(l10n: "menubar.activity_empty")
                        .font(.system(size: 11))
                        .foregroundStyle(OCTheme.muted)
                } else {
                    ForEach(tops) { proc in
                        HStack {
                            Text(proc.name)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(ByteFormat.string(Int64(proc.memoryBytes)))
                                .font(.system(size: 10).monospacedDigit())
                                .foregroundStyle(OCTheme.muted)
                        }
                    }
                }
                Text(L10n.format("menubar.reclaimable_brief", ByteFormat.string(engine.reclaimableBytes)))
                    .font(.system(size: 11))
                    .foregroundStyle(engine.reclaimableBytes > 0 ? OCTheme.accent : OCTheme.muted)
                    .padding(.top, 2)
            }
        }
    }

    private var networkTitle: String {
        if let ssid = network.ssid, !ssid.isEmpty { return ssid }
        return network.interfaceName.uppercased()
    }

    private var tipCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n: "menubar.tip_title")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(OCTheme.muted)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(colors: [OCTheme.sea, OCTheme.glass], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n: "menubar.tip_headline")
                        .font(.system(size: 13, weight: .semibold))
                    Text(l10n: "menubar.tip_body")
                        .font(.system(size: 11))
                        .foregroundStyle(OCTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                openMainWindow()
                DispatchQueue.main.async {
                    Task { await engine.runSmartCare() }
                }
            } label: {
                Text(l10n: "menubar.run_scan")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SeaButtonStyle())
            .disabled(engine.isScanning)
        }
        .padding(14)
        .background { tileBackground(corner: 16) }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                openMainWindow()
            } label: {
                Label(l10n: "menubar.open_short", systemImage: "macwindow")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SeaButtonStyle())

            Button {
                openMainWindow(then: .ocmmOpenSettings)
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 36, height: 34)
            }
            .buttonStyle(GhostButtonStyle())
            .help(L10n.string("menubar.settings"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color(red: 0.04, green: 0.08, blue: 0.16).opacity(0.55))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                }
        }
    }

    private func glassTile<Content: View>(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OCTheme.sea)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OCTheme.muted)
                    .lineLimit(1)
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background { tileBackground(corner: 14) }
    }

    private func tileBackground(corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(OCTheme.glass.opacity(0.22))
            }
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
    }

    private func batteryDetail(_ battery: BatteryStatus) -> String {
        if battery.percent == 100, battery.isCharging {
            return L10n.string("menubar.battery_full")
        }
        return battery.isCharging
            ? L10n.string("menubar.battery_charging")
            : L10n.string("menubar.battery_on_battery")
    }

    private func openMainWindow(then notification: Notification.Name? = nil) {
        preferences.hideDockIcon = false
        preferences.applyActivationPolicy()
        AppWindowActivator.bringMainToFront(openWindow: openWindow)
        if let notification {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: notification, object: nil)
            }
        }
    }
}

struct BatteryStatus {
    let percent: Int?
    let isCharging: Bool

    static func current() -> BatteryStatus {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let first = list.first,
              let info = IOPSGetPowerSourceDescription(blob, first)?.takeUnretainedValue() as? [String: Any]
        else {
            return BatteryStatus(percent: nil, isCharging: false)
        }

        let percent = info[kIOPSCurrentCapacityKey] as? Int
        let state = info[kIOPSPowerSourceStateKey] as? String
        let charging = state == kIOPSACPowerValue
            || (info[kIOPSIsChargingKey] as? Bool == true)
        return BatteryStatus(percent: percent, isCharging: charging)
    }
}

extension Notification.Name {
    static let ocmmOpenSettings = Notification.Name("ocmm.openSettings")
    static let ocmmOpenPerformance = Notification.Name("ocmm.openPerformance")
}
