import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: AppPreferences
    @Bindable var fda: FullDiskAccessManager
    @State private var protection = ProtectionStatus.snapshot()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                OCPageHeader(
                    title: L10n.string("settings.title"),
                    subtitle: L10n.string("settings.subtitle")
                )
                Text(Self.appVersionLabel)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(OCTheme.faint)
                permissions
                protectionSection
                language
                appearance
                launcher
                install
                if let message = preferences.lastInstallMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(OCTheme.muted)
                }
                quitSection
            }
            .padding(28)
        }
        .onAppear {
            preferences.refreshLaunchAtLoginStatus()
            fda.refresh()
            protection = ProtectionStatus.snapshot()
        }
    }

    private var permissions: some View {
        group(L10n.string("settings.permissions")) {
            HStack {
                Text(l10n: "settings.fda")
                Spacer()
                Text(fda.hasFullDiskAccess ? L10n.string("settings.fda.on") : L10n.string("settings.fda.off"))
                    .foregroundStyle(fda.hasFullDiskAccess ? OCTheme.success : OCTheme.accent)
            }
            Text(l10n: "settings.fda.help")
                .font(.caption)
                .foregroundStyle(OCTheme.muted)
            HStack(spacing: 10) {
                Button {
                    fda.openSystemSettings()
                    fda.startWatching { fda.refresh() }
                } label: {
                    Label(l10n: "onboarding.fda.open_settings", systemImage: "lock.shield")
                        .frame(minWidth: 160)
                }
                .buttonStyle(SeaButtonStyle())

                Button(L10n.string("onboarding.fda.recheck")) {
                    fda.refresh()
                }
                .buttonStyle(GhostButtonStyle())

                Button(L10n.string("settings.replay_onboarding")) {
                    preferences.onboardingComplete = false
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
    }

    private var protectionSection: some View {
        group(L10n.string("settings.protection")) {
            statusRow(
                L10n.string("settings.protection.filevault"),
                protection.fileVaultOn
            )
            statusRow(
                L10n.string("settings.protection.gatekeeper"),
                protection.gatekeeperOn
            )
            Text(l10n: "settings.protection.help")
                .font(.caption)
                .foregroundStyle(OCTheme.muted)
        }
    }

    private func statusRow(_ title: String, _ value: Bool?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(statusLabel(value))
                .foregroundStyle(value == true ? OCTheme.success : (value == false ? OCTheme.accent : OCTheme.muted))
        }
    }

    private func statusLabel(_ value: Bool?) -> String {
        switch value {
        case true: return L10n.string("common.on")
        case false: return L10n.string("common.off")
        case nil: return L10n.string("common.unknown")
        }
    }

    private var quitSection: some View {
        group(L10n.string("menubar.quit")) {
            Text(l10n: "settings.quit.help")
                .font(.caption)
                .foregroundStyle(OCTheme.muted)
            Button {
                NSApp.terminate(nil)
            } label: {
                Label(l10n: "menubar.quit", systemImage: "power")
                    .frame(minWidth: 140)
            }
            .buttonStyle(QuitButtonStyle())
        }
    }

    private var language: some View {
        group(L10n.string("settings.language")) {
            Picker(L10n.string("settings.language"), selection: $preferences.appLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(L10n.string(key: language.menuTitleKey)).tag(language)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(l10n: "settings.language.help")
                .font(.caption)
                .foregroundStyle(OCTheme.muted)
        }
    }

    private var appearance: some View {
        group(L10n.string("settings.appearance")) {
            Toggle(L10n.string("settings.show_menubar"), isOn: $preferences.showMenuBarIcon)
            Toggle(L10n.string("settings.hide_dock"), isOn: $preferences.hideDockIcon)
            Text(l10n: "settings.hide_dock.help")
                .font(.caption)
                .foregroundStyle(OCTheme.muted)
        }
    }

    private var launcher: some View {
        group(L10n.string("settings.launcher")) {
            Toggle(L10n.string("settings.launch_at_login"), isOn: $preferences.launchAtLogin)
            HStack {
                Text(l10n: "common.status")
                Spacer()
                Text(preferences.launchAtLoginStatusText)
                    .foregroundStyle(OCTheme.muted)
            }
            Button(L10n.string("settings.open_login_items")) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(GhostButtonStyle())
            Text(l10n: "settings.launch_help")
                .font(.caption)
                .foregroundStyle(OCTheme.muted)
        }
    }

    private var install: some View {
        group(L10n.string("settings.installation")) {
            HStack {
                Text(l10n: "settings.installed")
                Spacer()
                Text(preferences.isInstalledInApplications ? L10n.string("common.yes") : L10n.string("common.no"))
                    .foregroundStyle(preferences.isInstalledInApplications ? OCTheme.success : OCTheme.muted)
            }
            if preferences.isInstalledInApplications {
                Text(preferences.installedAppURL.path)
                    .font(.caption)
                    .foregroundStyle(OCTheme.muted)
                    .lineLimit(2)
            }
            HStack(spacing: 10) {
                Button {
                    preferences.installApp()
                } label: {
                    Label(
                        preferences.isInstalledInApplications
                            ? L10n.string("settings.reinstall")
                            : L10n.string("settings.install"),
                        systemImage: "square.and.arrow.down"
                    )
                    .frame(minWidth: 170)
                }
                .buttonStyle(SeaButtonStyle())

                Button {
                    preferences.uninstallApp()
                } label: {
                    Label(l10n: "settings.uninstall", systemImage: "trash")
                        .frame(minWidth: 110)
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(!preferences.isInstalledInApplications)

                if preferences.isInstalledInApplications {
                    Button(L10n.string("settings.reveal")) {
                        NSWorkspace.shared.activateFileViewerSelecting([AppInstaller.installedAppURL])
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            }
            Text(l10n: "settings.tip")
                .font(.caption)
                .foregroundStyle(OCTheme.muted)
        }
    }

    private static var appVersionLabel: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "MacCleaner \(short) (\(build))"
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
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
