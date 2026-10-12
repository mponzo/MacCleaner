import SwiftUI

struct PrivilegedHelperView: View {
    @Bindable var privileged: PrivilegedHelperEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                statusCards
                actions
                roadmap
                if let message = privileged.lastMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(OCTheme.muted)
                }
                if let error = privileged.lastError {
                    Text(error).foregroundStyle(.red)
                }
            }
            .padding(28)
        }
        .task { await privileged.refreshStatus() }
    }

    private var header: some View {
        OCPageHeader(
            title: L10n.string("priv.title"),
            subtitle: L10n.string("priv.subtitle")
        )
    }

    private var statusCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
            card(
                L10n.string("priv.bridge"),
                privileged.isBusy ? L10n.string("priv.busy") : L10n.string("priv.ready"),
                L10n.string("priv.osascript")
            )
            card(L10n.string("priv.system_caches"), ByteFormat.string(privileged.systemCacheBytes), "/Library/Caches")
            card(L10n.string("priv.system_logs"), ByteFormat.string(privileged.systemLogBytes), "/Library/Logs + /var/log")
            card(L10n.string("priv.broken_agents"), "\(privileged.brokenSystemAgents)", "/Library/LaunchAgents")
        }
    }

    private func card(_ title: String, _ value: String, _ subtitle: String) -> some View {
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
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(OCTheme.stroke))
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n: "priv.maintenance")
                .font(.title3.weight(.semibold))
            HStack(spacing: 12) {
                Button {
                    Task { await privileged.runFlushDNS() }
                } label: {
                    Label(l10n: "priv.flush_dns", systemImage: "network")
                        .frame(minWidth: 130)
                }
                .buttonStyle(SeaButtonStyle())
                .disabled(privileged.isBusy)

                Button {
                    Task { await privileged.runThinSnapshots() }
                } label: {
                    Label(l10n: "priv.thin_snapshots", systemImage: "externaldrive.badge.timemachine")
                        .frame(minWidth: 150)
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(privileged.isBusy)

                Button {
                    Task { await privileged.refreshStatus() }
                } label: {
                    Label(l10n: "priv.rescan", systemImage: "arrow.clockwise")
                }
                .disabled(privileged.isBusy)
            }
            Text(l10n: "priv.clean_help")
                .font(.caption)
                .foregroundStyle(OCTheme.muted)
        }
    }

    private var roadmap: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n: "priv.roadmap")
                .font(.title3.weight(.semibold))
            Text(l10n: "priv.roadmap.body")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(OCTheme.muted)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(OCTheme.stroke))
        }
    }
}
