import Charts
import SwiftUI

struct CleanupHistoryView: View {
    @Bindable var store: CleanupHistoryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedEntry: CleanupHistoryEntry?
    @State private var confirmClear = false
    @State private var chartAppeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                summaryRow
                if !store.entries.isEmpty {
                    trendCard
                }
                if store.entries.isEmpty {
                    emptyState
                } else {
                    sessionsList
                }
            }
            .padding(28)
        }
        .onAppear {
            guard !reduceMotion else {
                chartAppeared = true
                return
            }
            chartAppeared = false
            withAnimation(.easeOut(duration: 0.55).delay(0.05)) {
                chartAppeared = true
            }
        }
        .sheet(item: $selectedEntry) { entry in
            HistoryDetailSheet(entry: entry, store: store) {
                selectedEntry = nil
            }
        }
        .confirmationDialog(
            L10n.string("history.clear.confirm"),
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button(L10n.string("history.clear"), role: .destructive) {
                store.clear()
            }
            Button(L10n.string("common.cancel"), role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            OCPageHeader(
                title: L10n.string("history.title"),
                subtitle: L10n.string("history.subtitle")
            )
            Spacer()
            if !store.entries.isEmpty {
                Button(L10n.string("history.clear")) {
                    confirmClear = true
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            summaryTile(
                title: L10n.string("history.lifetime"),
                value: ByteFormat.string(store.lifetimeFreedBytes),
                detail: L10n.format("history.items_moved", Int64(store.lifetimeMovedCount))
            )
            summaryTile(
                title: L10n.string("history.last30"),
                value: ByteFormat.string(store.freedBytes(inLastDays: 30)),
                detail: L10n.format("history.sessions", Int64(store.entries.count))
            )
        }
    }

    private func summaryTile(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(OCTheme.font(11, weight: .semibold))
                .foregroundStyle(OCTheme.muted)
            Text(value)
                .font(OCTheme.font(28, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(OCTheme.ink)
            Text(detail)
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.faint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(OCTheme.stroke, lineWidth: 1)
        )
    }

    private var trendCard: some View {
        let points = store.dailyTotals(lastDays: 14)
        return VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("history.trend"))
                .font(OCTheme.font(14, weight: .semibold))
            Chart(points) { point in
                AreaMark(
                    x: .value("Day", point.day, unit: .day),
                    y: .value("Freed", chartAppeared ? Double(point.freedBytes) : 0)
                )
                .foregroundStyle(OCTheme.sea.opacity(0.28))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Day", point.day, unit: .day),
                    y: .value("Freed", chartAppeared ? Double(point.freedBytes) : 0)
                )
                .foregroundStyle(OCTheme.sea)
                .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Day", point.day, unit: .day),
                    y: .value("Freed", chartAppeared ? Double(point.freedBytes) : 0)
                )
                .foregroundStyle(OCTheme.sea)
                .symbolSize(point.freedBytes > 0 ? 28 : 0)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(OCTheme.stroke.opacity(0.5))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                                .font(OCTheme.font(10))
                                .foregroundStyle(OCTheme.faint)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(OCTheme.stroke.opacity(0.45))
                    AxisValueLabel {
                        if let bytes = value.as(Double.self) {
                            Text(ByteFormat.string(Int64(bytes)))
                                .font(OCTheme.font(10))
                                .foregroundStyle(OCTheme.faint)
                        }
                    }
                }
            }
            .frame(height: 180)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.55), value: chartAppeared)
        }
        .padding(16)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(OCTheme.stroke, lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(OCTheme.sea)
            Text(L10n.string("history.empty"))
                .font(OCTheme.font(16, weight: .semibold))
            Text(L10n.string("history.empty.detail"))
                .font(OCTheme.font(12))
                .foregroundStyle(OCTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(OCTheme.stroke, lineWidth: 1)
        )
    }

    private var sessionsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("history.sessions_title"))
                .font(OCTheme.font(14, weight: .semibold))
            ForEach(store.entries) { entry in
                Button {
                    selectedEntry = entry
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: entry.source.systemImage)
                            .foregroundStyle(OCTheme.sea)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.string(key: entry.source.titleKey))
                                .font(OCTheme.font(13, weight: .semibold))
                                .foregroundStyle(OCTheme.ink)
                            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                .font(OCTheme.font(11))
                                .foregroundStyle(OCTheme.muted)
                            if let detail = entry.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(OCTheme.font(11))
                                    .foregroundStyle(OCTheme.faint)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(ByteFormat.string(entry.freedBytes))
                                .font(OCTheme.font(13, weight: .semibold).monospacedDigit())
                                .foregroundStyle(OCTheme.ink)
                            Text(L10n.format("history.row_items", Int64(entry.movedCount)))
                                .font(OCTheme.font(11))
                                .foregroundStyle(OCTheme.muted)
                        }
                    }
                    .padding(12)
                    .background(OCTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(OCTheme.stroke, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct HistoryDetailSheet: View {
    let entry: CleanupHistoryEntry
    @Bindable var store: CleanupHistoryStore
    var onDismiss: () -> Void
    @State private var anchorView: NSView?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(L10n.string("history.detail.title"))
                    .font(OCTheme.font(18, weight: .bold))
                Spacer()
                Button(L10n.string("common.close")) { onDismiss() }
                    .buttonStyle(GhostButtonStyle())
            }

            CleanupShareCardView(entry: entry, lifetimeFreed: store.lifetimeFreedBytes)
                .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                Button {
                    CleanupShareExporter.share(
                        entry: entry,
                        lifetimeFreed: store.lifetimeFreedBytes,
                        relativeTo: anchorView
                    )
                } label: {
                    Label(L10n.string("history.share"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SeaButtonStyle())

                Button {
                    CleanupShareExporter.copyText(entry: entry)
                } label: {
                    Label(L10n.string("history.copy"), systemImage: "doc.on.doc")
                }
                .buttonStyle(GhostButtonStyle())

                Spacer()

                Button(role: .destructive) {
                    store.remove(entry.id)
                    onDismiss()
                } label: {
                    Text(L10n.string("history.delete_entry"))
                }
                .buttonStyle(GhostButtonStyle())
            }

            SharingAnchor(view: $anchorView)
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)
        }
        .padding(24)
        .frame(width: 480)
        .background(OCTheme.canvas)
    }
}

private struct SharingAnchor: NSViewRepresentable {
    @Binding var view: NSView?

    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        DispatchQueue.main.async { view = v }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { view = nsView }
    }
}
