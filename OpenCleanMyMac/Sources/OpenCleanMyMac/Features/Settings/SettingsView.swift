import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: AppPreferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                OCPageHeader(
                    title: L10n.string("settings.title"),
                    subtitle: L10n.string("settings.subtitle")
                )
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
        .onAppear { preferences.refreshLaunchAtLoginStatus() }
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
