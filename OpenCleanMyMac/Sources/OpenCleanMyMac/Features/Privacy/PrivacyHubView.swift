import AppKit
import SwiftUI

@MainActor
@Observable
final class PrivacyHubEngine {
    var purgeable = PurgeableSpace.measure()
    var tccEntries: [TCCEntry] = []
    var tccError: String?
    var isRefreshing = false
    var isPurging = false
    var message: String?

    func refresh() {
        isRefreshing = true
        purgeable = PurgeableSpace.measure()
        let tcc = TCCInventory.loadUserEntries()
        tccEntries = tcc.entries
        tccError = tcc.error
        isRefreshing = false
    }

    func purgeViaThinSnapshots() async {
        isPurging = true
        message = nil
        let result = await PrivilegedBridge.thinLocalSnapshots()
        message = result.success
            ? L10n.string("privacy.purge.ok")
            : (result.message.isEmpty ? L10n.string("privacy.purge.fail") : result.message)
        purgeable = PurgeableSpace.measure()
        isPurging = false
    }

    func openPrivacyPane(_ anchor: String) {
        // Best-effort deep links into System Settings Privacy & Security.
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?\(anchor)",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(anchor)"
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) { return }
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }

    func openSafariPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Preference.Security?Privacy") {
            NSWorkspace.shared.open(url)
        }
        // Also reveal Safari settings path guidance via browser prefs.
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Safari.app"))
    }

    func openChromeSettings() {
        let chrome = URL(fileURLWithPath: "/Applications/Google Chrome.app")
        if FileManager.default.fileExists(atPath: chrome.path) {
            NSWorkspace.shared.open(chrome)
        }
    }
}

struct PrivacyHubView: View {
    @Bindable var engine: PrivacyHubEngine
    @Bindable var fda: FullDiskAccessManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    OCPageHeader(
                        title: L10n.string("privacy.title"),
                        subtitle: L10n.string("privacy.subtitle")
                    )
                    Spacer()
                    Button {
                        engine.refresh()
                        fda.refresh()
                    } label: {
                        Label(l10n: "common.refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(GhostButtonStyle())
                }

                purgeableCard
                browserCard
                tccCard

                if let message = engine.message {
                    Text(message).foregroundStyle(OCTheme.muted)
                }
            }
            .padding(28)
        }
        .onAppear { engine.refresh() }
    }

    private var purgeableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n: "privacy.purgeable")
                .font(OCTheme.font(15, weight: .semibold))
            Text(l10n: "privacy.purgeable.help")
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.muted)

            HStack(spacing: 24) {
                metric(L10n.string("privacy.purgeable.free"), ByteFormat.string(engine.purgeable.freeBytes))
                metric(L10n.string("privacy.purgeable.amount"), ByteFormat.string(engine.purgeable.purgeableBytes))
                metric(L10n.string("privacy.purgeable.important"), ByteFormat.string(engine.purgeable.availableImportantBytes))
            }

            Button {
                Task { await engine.purgeViaThinSnapshots() }
            } label: {
                Label(l10n: "privacy.purge.action", systemImage: "externaldrive.badge.timemachine")
            }
            .buttonStyle(SeaButtonStyle())
            .disabled(engine.isPurging || !engine.purgeable.hasPurgeable)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(OCTheme.stroke))
    }

    private var browserCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n: "privacy.browser")
                .font(OCTheme.font(15, weight: .semibold))
            Text(l10n: "privacy.browser.help")
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.muted)

            guideRow(
                title: L10n.string("privacy.safari"),
                body: L10n.string("privacy.safari.detail"),
                actionTitle: L10n.string("privacy.safari.open")
            ) {
                engine.openSafariPrivacy()
            }

            guideRow(
                title: L10n.string("privacy.chrome"),
                body: L10n.string("privacy.chrome.detail"),
                actionTitle: L10n.string("privacy.chrome.open")
            ) {
                engine.openChromeSettings()
            }

            Text(l10n: "privacy.browser.caches_hint")
                .font(OCTheme.font(11))
                .foregroundStyle(OCTheme.faint)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(OCTheme.stroke))
    }

    private var tccCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n: "privacy.tcc")
                .font(OCTheme.font(15, weight: .semibold))
            Text(l10n: "privacy.tcc.help")
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.muted)

            HStack(spacing: 10) {
                Button(L10n.string("privacy.tcc.open_fda")) {
                    fda.openSystemSettings()
                }
                .buttonStyle(GhostButtonStyle())
                Button(L10n.string("privacy.tcc.open_camera")) {
                    engine.openPrivacyPane("Privacy_Camera")
                }
                .buttonStyle(GhostButtonStyle())
                Button(L10n.string("privacy.tcc.open_mic")) {
                    engine.openPrivacyPane("Privacy_Microphone")
                }
                .buttonStyle(GhostButtonStyle())
            }

            if let err = engine.tccError {
                Text(err).foregroundStyle(OCTheme.accent)
            } else if engine.tccEntries.isEmpty {
                Text(l10n: "privacy.tcc.empty").foregroundStyle(OCTheme.muted)
            } else {
                ForEach(engine.tccEntries.prefix(40)) { entry in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(TCCInventory.friendlyServiceName(entry.service))
                                .font(OCTheme.font(13, weight: .medium))
                            Text(entry.client)
                                .font(OCTheme.font(11))
                                .foregroundStyle(OCTheme.muted)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(entry.allowed ? L10n.string("common.on") : L10n.string("common.off"))
                            .foregroundStyle(entry.allowed ? OCTheme.success : OCTheme.muted)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(OCTheme.stroke))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(OCTheme.font(10, weight: .semibold))
                .foregroundStyle(OCTheme.muted)
            Text(value)
                .font(OCTheme.font(18, weight: .semibold).monospacedDigit())
        }
    }

    private func guideRow(title: String, body: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(OCTheme.font(13, weight: .semibold))
                Text(body).font(OCTheme.font(12)).foregroundStyle(OCTheme.muted)
            }
            Spacer()
            Button(actionTitle, action: action)
                .buttonStyle(GhostButtonStyle())
        }
        .padding(.vertical, 4)
    }
}
