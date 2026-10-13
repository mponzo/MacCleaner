import AppKit
import SwiftUI

struct SimilarPhotosView: View {
    @Bindable var engine: SimilarPhotosEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                OCPageHeader(
                    title: L10n.string("photos.title"),
                    subtitle: L10n.string("photos.subtitle")
                )

                Text(l10n: "photos.disclaimer")
                    .font(.caption)
                    .foregroundStyle(OCTheme.muted)

                HStack(spacing: 10) {
                    Button {
                        engine.chooseFolder()
                    } label: {
                        Label(l10n: "photos.choose", systemImage: "photo.on.rectangle")
                            .frame(minWidth: 150)
                    }
                    .buttonStyle(SeaButtonStyle())
                    .disabled(engine.isScanning)

                    if engine.rootURL != nil {
                        Button {
                            engine.startScan()
                        } label: {
                            Label(l10n: "photos.rescan", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(GhostButtonStyle())
                        .disabled(engine.isScanning)
                    }

                    if engine.isScanning {
                        Button {
                            engine.stop()
                        } label: {
                            Label(l10n: "smartcare.stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(GhostButtonStyle())
                        ProgressView().controlSize(.small).tint(OCTheme.sea)
                    }
                    Spacer()
                }

                if let root = engine.rootURL {
                    Text(root.path)
                        .font(.caption)
                        .foregroundStyle(OCTheme.muted)
                        .lineLimit(2)
                }

                Text(engine.progressLabel)
                    .font(.callout)
                    .foregroundStyle(OCTheme.muted)

                if engine.hitLimit {
                    Text(l10n: "photos.limit")
                        .font(.caption)
                        .foregroundStyle(OCTheme.accent)
                }

                if engine.groups.isEmpty, !engine.isScanning {
                    ContentUnavailableView(
                        L10n.string("photos.empty"),
                        systemImage: "photo.stack",
                        description: Text(l10n: "photos.empty.detail")
                    )
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    ForEach(engine.groups) { group in
                        groupCard(group)
                    }
                }
            }
            .padding(28)
        }
    }

    private func groupCard(_ group: SimilarPhotoGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.format("photos.group_title", Int64(group.photos.count)))
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                ForEach(group.photos) { photo in
                    VStack(spacing: 6) {
                        PhotoThumb(url: photo.url)
                            .frame(height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text(photo.url.lastPathComponent)
                            .font(.caption2)
                            .lineLimit(1)
                        Button(L10n.string("photos.reveal")) {
                            NSWorkspace.shared.activateFileViewerSelecting([photo.url])
                        }
                        .buttonStyle(GhostButtonStyle())
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                }
        }
    }
}

private struct PhotoThumb: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Color.white.opacity(0.06)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(OCTheme.muted)
            }
        }
        .task(id: url) {
            image = NSImage(contentsOf: url)
        }
    }
}
