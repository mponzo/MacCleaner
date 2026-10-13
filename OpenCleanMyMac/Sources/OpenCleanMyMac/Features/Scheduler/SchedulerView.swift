import SwiftUI

struct SchedulerView: View {
    @Bindable var scheduler: CleanupScheduler

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                OCPageHeader(
                    title: L10n.string("sched.title"),
                    subtitle: L10n.string("sched.subtitle")
                )

                VStack(alignment: .leading, spacing: 14) {
                    Toggle(L10n.string("sched.enable"), isOn: Binding(
                        get: { scheduler.isEnabled },
                        set: { scheduler.setEnabled($0) }
                    ))

                    Picker(L10n.string("sched.interval"), selection: $scheduler.interval) {
                        ForEach(ScheduleInterval.allCases) { interval in
                            Text(L10n.string(key: interval.titleKey)).tag(interval)
                        }
                    }
                    .disabled(!scheduler.isEnabled)

                    Toggle(L10n.string("sched.auto_clean"), isOn: $scheduler.autoCleanAfterScan)
                        .disabled(!scheduler.isEnabled)

                    HStack {
                        Text(l10n: "sched.threshold")
                        Spacer()
                        Stepper(value: $scheduler.thresholdMB, in: 10...5_000, step: 10) {
                            Text("\(scheduler.thresholdMB) MB")
                                .monospacedDigit()
                        }
                        .disabled(!scheduler.isEnabled || !scheduler.autoCleanAfterScan)
                    }

                    Text(l10n: "sched.help")
                        .font(.caption)
                        .foregroundStyle(OCTheme.muted)
                }
                .padding(16)
                .background(cardBackground)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(l10n: "sched.status")
                        Spacer()
                        Text(scheduler.statusLabel)
                            .foregroundStyle(OCTheme.muted)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text(l10n: "sched.last_run")
                        Spacer()
                        Text(scheduler.lastRunAt.map(Self.formatDate) ?? L10n.string("sched.never"))
                            .foregroundStyle(OCTheme.muted)
                    }
                    HStack {
                        Text(l10n: "sched.next_run")
                        Spacer()
                        Text(scheduler.nextRunAt.map(Self.formatDate) ?? L10n.string("sched.not_scheduled"))
                            .foregroundStyle(OCTheme.muted)
                    }

                    Button {
                        scheduler.runNow()
                    } label: {
                        Label(l10n: "sched.run_now", systemImage: "play.fill")
                            .frame(minWidth: 140)
                    }
                    .buttonStyle(SeaButtonStyle())
                    .disabled(scheduler.isRunning)
                    .padding(.top, 6)
                }
                .padding(16)
                .background(cardBackground)
            }
            .padding(28)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(OCTheme.glass.opacity(0.18))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
    }

    private static func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
