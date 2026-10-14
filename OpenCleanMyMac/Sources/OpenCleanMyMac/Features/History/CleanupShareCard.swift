import AppKit
import SwiftUI

/// Fixed-size shareable card — rendered locally; never uploaded.
struct CleanupShareCardView: View {
    let entry: CleanupHistoryEntry
    var lifetimeFreed: Int64 = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                OCBrandIcon()
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MacCleaner")
                        .font(OCTheme.font(18, weight: .bold))
                        .foregroundStyle(OCTheme.ink)
                    Text(L10n.string("history.share.tagline"))
                        .font(OCTheme.font(11))
                        .foregroundStyle(OCTheme.muted)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.string("history.share.freed"))
                    .font(OCTheme.font(12, weight: .semibold))
                    .foregroundStyle(OCTheme.sea)
                Text(ByteFormat.string(entry.freedBytes))
                    .font(OCTheme.font(40, weight: .bold))
                    .foregroundStyle(OCTheme.ink)
                    .monospacedDigit()
            }

            HStack(spacing: 16) {
                labelValue(
                    L10n.string("history.share.items"),
                    "\(entry.movedCount)"
                )
                labelValue(
                    L10n.string("history.share.source"),
                    L10n.string(key: entry.source.titleKey)
                )
            }

            if lifetimeFreed > 0 {
                Text(L10n.format("history.share.lifetime", ByteFormat.string(lifetimeFreed)))
                    .font(OCTheme.font(11))
                    .foregroundStyle(OCTheme.muted)
            }

            HStack {
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(OCTheme.font(11))
                    .foregroundStyle(OCTheme.faint)
                Spacer()
                Text(L10n.string("history.share.local"))
                    .font(OCTheme.font(10, weight: .semibold))
                    .foregroundStyle(OCTheme.sea)
            }
        }
        .padding(28)
        .frame(width: 420, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(OCTheme.canvasElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(OCTheme.stroke, lineWidth: 1)
        )
    }

    private func labelValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(OCTheme.font(10, weight: .semibold))
                .foregroundStyle(OCTheme.faint)
            Text(value)
                .font(OCTheme.font(13, weight: .semibold))
                .foregroundStyle(OCTheme.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum CleanupShareExporter {
    @MainActor
    static func share(entry: CleanupHistoryEntry, lifetimeFreed: Int64, relativeTo view: NSView?) {
        let card = CleanupShareCardView(entry: entry, lifetimeFreed: lifetimeFreed)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        guard let image = renderer.nsImage else { return }

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacCleaner-cleanup-\(entry.id.uuidString.prefix(8)).png")
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return }
        try? png.write(to: temp)

        let text = [
            L10n.format("history.share.text_freed", ByteFormat.string(entry.freedBytes)),
            L10n.format("history.share.text_items", Int64(entry.movedCount)),
            L10n.string(key: entry.source.titleKey),
            L10n.string("history.share.local"),
        ].joined(separator: "\n")

        let picker = NSSharingServicePicker(items: [temp, text])
        if let view {
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        } else if let window = NSApp.keyWindow, let content = window.contentView {
            let rect = NSRect(x: content.bounds.midX - 1, y: content.bounds.midY - 1, width: 2, height: 2)
            picker.show(relativeTo: rect, of: content, preferredEdge: .minY)
        }
    }

    @MainActor
    static func copyText(entry: CleanupHistoryEntry) {
        let text = [
            L10n.format("history.share.text_freed", ByteFormat.string(entry.freedBytes)),
            L10n.format("history.share.text_items", Int64(entry.movedCount)),
            L10n.string(key: entry.source.titleKey),
            entry.date.formatted(date: .abbreviated, time: .shortened),
            L10n.string("history.share.local"),
        ].joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
