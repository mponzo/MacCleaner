import AppKit
import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppPreferences {
    static let shared = AppPreferences()

    private enum Keys {
        static let showMenuBarIcon = "prefs.showMenuBarIcon"
        static let launchAtLogin = "prefs.launchAtLogin"
        static let hideDockIcon = "prefs.hideDockIcon"
        static let appLanguage = "prefs.appLanguage"
        static let onboardingComplete = "prefs.onboardingComplete"
        /// Bump to re-show onboarding (e.g. new FDA slide) for existing installs.
        static let onboardingSchema = "prefs.onboardingSchema"
    }

    /// Current first-run coach mark schema. Increment when slides materially change.
    static let currentOnboardingSchema = 2

    private var isSyncingLoginItem = false
    private var isBootstrapping = true

    var showMenuBarIcon: Bool {
        didSet {
            guard !isBootstrapping else { return }
            UserDefaults.standard.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon)
        }
    }

    var hideDockIcon: Bool {
        didSet {
            guard !isBootstrapping else { return }
            UserDefaults.standard.set(hideDockIcon, forKey: Keys.hideDockIcon)
            applyActivationPolicy()
        }
    }

    var launchAtLogin: Bool {
        didSet {
            guard !isBootstrapping else { return }
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            guard !isSyncingLoginItem else { return }
            syncLaunchAtLogin()
        }
    }

    /// In-app language; changing refreshes UI via `languageRevision`.
    var appLanguage: AppLanguage {
        didSet {
            guard !isBootstrapping else { return }
            UserDefaults.standard.set(appLanguage.rawValue, forKey: Keys.appLanguage)
            L10n.apply(appLanguage)
            languageRevision &+= 1
            refreshLaunchAtLoginStatus()
        }
    }

    /// Bumped when language changes so SwiftUI rebuilds localized views.
    private(set) var languageRevision: UInt = 0

    var launchAtLoginStatusText: String = ""
    var lastInstallMessage: String?

    /// First-launch coach marks (PureMac-style). False until the user finishes onboarding.
    var onboardingComplete: Bool {
        didSet {
            guard !isBootstrapping else { return }
            UserDefaults.standard.set(onboardingComplete, forKey: Keys.onboardingComplete)
        }
    }

    var isInstalledInApplications: Bool { AppInstaller.isInstalled }
    var installedAppURL: URL { AppInstaller.installedAppURL }

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Keys.showMenuBarIcon) == nil {
            defaults.set(true, forKey: Keys.showMenuBarIcon)
        }
        showMenuBarIcon = defaults.bool(forKey: Keys.showMenuBarIcon)
        hideDockIcon = defaults.bool(forKey: Keys.hideDockIcon)
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        let storedSchema = defaults.integer(forKey: Keys.onboardingSchema)
        if storedSchema < Self.currentOnboardingSchema {
            // New FDA / permissions coach marks — show the slider again.
            defaults.set(false, forKey: Keys.onboardingComplete)
            defaults.set(Self.currentOnboardingSchema, forKey: Keys.onboardingSchema)
            onboardingComplete = false
        } else {
            onboardingComplete = defaults.bool(forKey: Keys.onboardingComplete)
        }
        let stored = defaults.string(forKey: Keys.appLanguage) ?? AppLanguage.system.rawValue
        appLanguage = AppLanguage(rawValue: stored) ?? .system
        L10n.apply(appLanguage)
        launchAtLoginStatusText = "…"
        isBootstrapping = false
    }

    /// Call after AppKit has created `NSApp` (e.g. root view `.onAppear`).
    func finishLaunchSetup() {
        refreshLaunchAtLoginStatus()
        applyActivationPolicy()
    }

    func applyActivationPolicy() {
        guard NSApp != nil else { return }
        NSApp.setActivationPolicy(hideDockIcon ? .accessory : .regular)
        if !hideDockIcon {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func refreshLaunchAtLoginStatus() {
        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLoginStatusText = L10n.string("settings.login.enabled")
        case .notRegistered:
            launchAtLoginStatusText = L10n.string("settings.login.not_registered")
        case .requiresApproval:
            launchAtLoginStatusText = L10n.string("settings.login.needs_approval")
        case .notFound:
            launchAtLoginStatusText = L10n.string("settings.login.unavailable")
        @unknown default:
            launchAtLoginStatusText = L10n.string("settings.login.unknown")
        }
    }

    private func syncLaunchAtLogin() {
        isSyncingLoginItem = true
        defer {
            isSyncingLoginItem = false
            refreshLaunchAtLoginStatus()
        }

        do {
            if launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            lastInstallMessage = nil
        } catch {
            lastInstallMessage = error.localizedDescription
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    func installApp() {
        do {
            let url = try AppInstaller.install()
            lastInstallMessage = L10n.format("settings.installed_to", url.path)
            refreshLaunchAtLoginStatus()
        } catch {
            lastInstallMessage = error.localizedDescription
        }
    }

    func uninstallApp(removeLoginItem: Bool = true) {
        do {
            if removeLoginItem, SMAppService.mainApp.status == .enabled {
                try? SMAppService.mainApp.unregister()
                isSyncingLoginItem = true
                launchAtLogin = false
                isSyncingLoginItem = false
            }
            try AppInstaller.uninstall()
            lastInstallMessage = L10n.string("settings.uninstalled")
            refreshLaunchAtLoginStatus()
        } catch {
            lastInstallMessage = error.localizedDescription
        }
    }
}
