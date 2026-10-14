import SwiftUI

struct UpdatesView: View {
    @Bindable var updater: AppUpdateEngine
    @Bindable var preferences: AppPreferences
    @Bindable var brew: HomebrewCaskEngine
    var onOpenAppUpdates: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                OCPageHeader(
                    title: L10n.string("updates.title"),
                    subtitle: L10n.string("updates.subtitle")
                )

                currentVersionCard
                remoteCard
                HomebrewCaskSection(brew: brew, onOpenFullPage: onOpenAppUpdates)
                privacyNote

                if let error = updater.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(OCTheme.danger)
                }
            }
            .padding(28)
        }
        .task {
            // Always refresh when opening the section — including when already up to date.
            await updater.checkForUpdates()
        }
    }

    private var currentVersionCard: some View {
        group(L10n.string("updates.installed")) {
            row(L10n.string("updates.version"), updater.installedVersion)
            row(L10n.string("updates.build"), "\(updater.installedBuild)")
            if let checked = updater.lastCheckedAt {
                row(
                    L10n.string("updates.last_check"),
                    checked.formatted(date: .abbreviated, time: .shortened)
                )
            }

            if updater.remote != nil, !updater.updateAvailable, !updater.isChecking {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(OCTheme.success)
                    Text(l10n: "updates.up_to_date")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(OCTheme.success)
                }
                .padding(.top, 4)
            }
        }
    }

    private var remoteCard: some View {
        group(L10n.string("updates.repository")) {
            if let remote = updater.remote {
                row(L10n.string("updates.latest"), remote.version)
                row(L10n.string("updates.build"), "\(remote.build)")
                let notes = remote.localizedNotes(language: preferences.appLanguage)
                if !notes.isEmpty {
                    Text(notes)
                        .font(.callout)
                        .foregroundStyle(OCTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if updater.isChecking {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small).tint(OCTheme.sea)
                    Text(l10n: "updates.checking")
                        .foregroundStyle(OCTheme.muted)
                }
            } else {
                Text(l10n: "updates.not_checked")
                    .foregroundStyle(OCTheme.muted)
            }

            if let status = updater.statusMessage {
                Text(status)
                    .font(.callout)
                    .foregroundStyle(updater.updateAvailable ? OCTheme.sea : OCTheme.success)
            }

            // Keep check + install controls visible even when already up to date.
            HStack(spacing: 10) {
                Button {
                    Task { await updater.checkForUpdates() }
                } label: {
                    Label(l10n: "updates.check", systemImage: "arrow.triangle.2.circlepath")
                        .frame(minWidth: 160)
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(updater.isChecking || updater.isUpdating)

                Button {
                    Task { await updater.installUpdateAndRelaunch() }
                } label: {
                    Label(
                        updater.isUpdating
                            ? L10n.string("updates.installing")
                            : L10n.string("updates.install"),
                        systemImage: "square.and.arrow.down"
                    )
                    .frame(minWidth: 180)
                }
                .buttonStyle(SeaButtonStyle())
                .disabled(!updater.updateAvailable || updater.isChecking || updater.isUpdating)

                if updater.isUpdating || updater.isChecking {
                    ProgressView()
                        .controlSize(.small)
                        .tint(OCTheme.sea)
                }
            }
        }
    }

    private var privacyNote: some View {
        group(L10n.string("updates.privacy")) {
            Text(l10n: "updates.privacy.body")
                .font(.caption)
                .foregroundStyle(OCTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(OCTheme.muted)
                .monospacedDigit()
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(OCTheme.font(15, weight: .semibold))
                .foregroundStyle(OCTheme.ink)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(OCTheme.violet.opacity(0.22))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                }
                .shadow(color: OCTheme.shadow.opacity(0.35), radius: 8, x: 0, y: 3)
        }
    }
}
