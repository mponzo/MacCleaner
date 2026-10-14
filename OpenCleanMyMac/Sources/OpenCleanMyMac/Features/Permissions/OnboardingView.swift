import AppKit
import SwiftUI

/// First-launch onboarding. Slide 2 mirrors PureMac's Full Disk Access coach mark
/// (REA: `OnboardingView` / `FDADemoView`, Privacy_AllFiles deep link).
struct OnboardingView: View {
    @Bindable var preferences: AppPreferences
    @Bindable var fda: FullDiskAccessManager

    /// Start on Full Disk Access (page 0) — the permission slider users expect first.
    @State private var page = 0

    private let pageCount = 3

    var body: some View {
        ZStack {
            OCScreenBackground()
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                Group {
                    switch page {
                    case 0: fullDiskPage
                    case 1: welcomePage
                    default: readyPage
                    }
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, 36)
                Spacer(minLength: 16)
                footer
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .preferredColorScheme(.dark)
        .foregroundStyle(OCTheme.ink)
        .onAppear {
            fda.refresh()
            // Trigger Desktop/Documents/Downloads TCC prompts on first slide.
            fda.requestStandardFolderAccess()
            if page == 0, !fda.hasFullDiskAccess {
                fda.startWatching()
            }
        }
        .onChange(of: page) { _, newValue in
            if newValue == 0, !fda.hasFullDiskAccess {
                fda.startWatching()
            } else {
                fda.stopWatching()
            }
        }
        .onDisappear {
            fda.stopWatching()
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 18) {
            Image(systemName: "internaldrive.fill")
                .font(OCTheme.font(52, weight: .semibold))
                .foregroundStyle(OCTheme.sea)
            Text(l10n: "onboarding.welcome.title")
                .font(OCTheme.font(34, weight: .bold))
                .multilineTextAlignment(.center)
            Text(l10n: "onboarding.welcome.body")
                .font(OCTheme.font(15))
                .foregroundStyle(OCTheme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
    }

    private var fullDiskPage: some View {
        VStack(spacing: 16) {
            Text(
                fda.hasFullDiskAccess
                    ? L10n.string("onboarding.fda.title_granted")
                    : L10n.string("onboarding.fda.title")
            )
            .font(OCTheme.font(30, weight: .bold))
            .multilineTextAlignment(.center)

            Text(
                fda.hasFullDiskAccess
                    ? L10n.string("onboarding.fda.body_granted")
                    : L10n.string("onboarding.fda.body")
            )
            .font(OCTheme.font(14))
            .foregroundStyle(OCTheme.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 560)

            fdaDemoCard

            Text(l10n: "onboarding.fda.path")
                .font(OCTheme.font(12, weight: .medium))
                .foregroundStyle(OCTheme.faint)

            if fda.hasFullDiskAccess {
                Label(l10n: "onboarding.fda.ready", systemImage: "checkmark.circle.fill")
                    .font(OCTheme.font(14, weight: .semibold))
                    .foregroundStyle(OCTheme.success)
            } else if fda.isWatching {
                Label(l10n: "onboarding.fda.watching", systemImage: "eye")
                    .font(OCTheme.font(13, weight: .medium))
                    .foregroundStyle(OCTheme.sea)
            }

            HStack(spacing: 10) {
                Button {
                    fda.openSystemSettings()
                    fda.startWatching()
                } label: {
                    Label(l10n: "onboarding.fda.open_settings", systemImage: "gearshape")
                        .frame(minWidth: 180)
                }
                .buttonStyle(SeaButtonStyle())

                Button {
                    fda.refresh()
                } label: {
                    Label(l10n: "onboarding.fda.recheck", systemImage: "arrow.clockwise")
                }
                .buttonStyle(GhostButtonStyle())
            }
            .padding(.top, 4)
        }
    }

    private var fdaDemoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(Color.red.opacity(0.85)).frame(width: 10, height: 10)
                Circle().fill(Color.yellow.opacity(0.85)).frame(width: 10, height: 10)
                Circle().fill(Color.green.opacity(0.85)).frame(width: 10, height: 10)
                Spacer()
                Text(l10n: "onboarding.fda.window_title")
                    .font(OCTheme.font(12, weight: .semibold))
                    .foregroundStyle(OCTheme.muted)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider().opacity(0.25)

            VStack(spacing: 0) {
                demoRow(name: "Finder", enabled: true, highlight: false)
                demoRow(name: "MacCleaner", enabled: fda.hasFullDiskAccess, highlight: true)
                demoRow(name: L10n.string("onboarding.fda.terminal"), enabled: true, highlight: false)
            }
            .padding(.vertical, 6)
        }
        .frame(maxWidth: 420)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(OCTheme.glass.opacity(0.18))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                }
        }
        .padding(.vertical, 8)
    }

    private func demoRow(name: String, enabled: Bool, highlight: Bool) -> some View {
        HStack {
            Image(systemName: highlight ? "internaldrive.fill" : "app.fill")
                .foregroundStyle(highlight ? OCTheme.sea : OCTheme.muted)
                .frame(width: 22)
            Text(name)
                .font(.system(size: 13, weight: highlight ? .semibold : .regular))
            Spacer()
            Toggle("", isOn: .constant(enabled))
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(true)
                .tint(OCTheme.success)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(highlight ? OCTheme.sea.opacity(0.12) : Color.clear)
    }

    private var readyPage: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(OCTheme.font(52, weight: .semibold))
                .foregroundStyle(OCTheme.success)
            Text(l10n: "onboarding.ready.title")
                .font(OCTheme.font(32, weight: .bold))
            Text(
                fda.hasFullDiskAccess
                    ? L10n.string("onboarding.ready.body_fda")
                    : L10n.string("onboarding.ready.body_limited")
            )
            .font(OCTheme.font(14))
            .foregroundStyle(OCTheme.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 520)
        }
    }

    private var footer: some View {
        HStack {
            Button(L10n.string("onboarding.back")) {
                page = max(0, page - 1)
            }
            .buttonStyle(GhostButtonStyle())
            .opacity(page == 0 ? 0 : 1)
            .disabled(page == 0)

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? OCTheme.sea : Color.white.opacity(0.25))
                        .frame(width: index == page ? 22 : 7, height: 7)
                }
            }

            Spacer()

            if page < pageCount - 1 {
                Button(L10n.string("onboarding.continue")) {
                    if page == 0 {
                        fda.refresh()
                    }
                    page += 1
                }
                .buttonStyle(SeaButtonStyle())
            } else {
                Button(L10n.string("onboarding.get_started")) {
                    fda.stopWatching()
                    UserDefaults.standard.set(
                        AppPreferences.currentOnboardingSchema,
                        forKey: "prefs.onboardingSchema"
                    )
                    preferences.onboardingComplete = true
                }
                .buttonStyle(AccentButtonStyle())
            }
        }
    }
}
