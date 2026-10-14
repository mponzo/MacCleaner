import SwiftUI

struct StartupView: View {
    @Bindable var engine: StartupEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    OCPageHeader(
                        title: L10n.string("startup.title"),
                        subtitle: L10n.string("startup.subtitle")
                    )
                    Spacer()
                    Button {
                        Task { await engine.refresh() }
                    } label: {
                        Label(l10n: "common.refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(engine.isRefreshing || engine.isWorking)
                }

                loginItemsCard
                agentsCard
                snapshotsCard

                if let msg = engine.lastMessage {
                    Text(msg).foregroundStyle(OCTheme.muted)
                }
                if let err = engine.errorMessage {
                    Text(err).foregroundStyle(OCTheme.danger)
                }
                Text(engine.progressLabel)
                    .font(OCTheme.font(12))
                    .foregroundStyle(OCTheme.faint)
            }
            .padding(28)
        }
        .task {
            if engine.launchAgents.isEmpty {
                await engine.refresh()
            }
        }
    }

    private var loginItemsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n: "startup.login_items")
                .font(OCTheme.font(15, weight: .semibold))
            Text(l10n: "startup.login_items.help")
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.muted)
            Button {
                engine.openLoginItems()
            } label: {
                Label(l10n: "settings.open_login_items", systemImage: "person.crop.circle.badge.checkmark")
            }
            .buttonStyle(SeaButtonStyle())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(OCTheme.stroke))
    }

    private var agentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l10n: "startup.agents")
                    .font(OCTheme.font(15, weight: .semibold))
                Spacer()
                Text(L10n.format("perf.agents.broken_count", Int64(engine.brokenCount)))
                    .foregroundStyle(engine.brokenCount > 0 ? OCTheme.accent : OCTheme.muted)
                Button(L10n.string("perf.agents.remove")) {
                    Task { await engine.removeSelectedAgents() }
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(engine.selectedAgentBytes == 0 || engine.isWorking)
            }
            Text(l10n: "perf.agents.help")
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.muted)

            ForEach(engine.launchAgents.prefix(50)) { agent in
                HStack(alignment: .top, spacing: 10) {
                    if agent.isUserDomain {
                        Toggle("", isOn: Binding(
                            get: { agent.isSelected },
                            set: { _ in engine.toggleAgent(agent.id) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                        .disabled(engine.isWorking)
                    } else {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(OCTheme.muted)
                            .frame(width: 18)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(agent.label).font(OCTheme.font(13, weight: .medium))
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
                            .font(OCTheme.font(11))
                            .foregroundStyle(OCTheme.muted)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        engine.revealAgent(agent.url)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(OCTheme.sea)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(OCTheme.stroke))
    }

    private var snapshotsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l10n: "startup.snapshots")
                    .font(OCTheme.font(15, weight: .semibold))
                Spacer()
                Button(L10n.string("startup.thin_all")) {
                    Task { await engine.thinAllSnapshots() }
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(engine.isWorking)

                Button(L10n.string("startup.delete_selected")) {
                    Task { await engine.deleteSelectedSnapshots() }
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(engine.snapshots.filter(\.isSelected).isEmpty || engine.isWorking)
            }
            Text(l10n: "startup.snapshots.help")
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.muted)

            if engine.snapshots.isEmpty {
                Text(l10n: "startup.snapshots.empty")
                    .foregroundStyle(OCTheme.muted)
            } else {
                ForEach(engine.snapshots) { snap in
                    Toggle(isOn: Binding(
                        get: { snap.isSelected },
                        set: { _ in engine.toggleSnapshot(snap.id) }
                    )) {
                        Text(snap.dateString)
                            .font(OCTheme.font(13).monospacedDigit())
                    }
                    .toggleStyle(.checkbox)
                    .disabled(engine.isWorking)
                }
            }
        }
        .padding(16)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(OCTheme.stroke))
    }
}
