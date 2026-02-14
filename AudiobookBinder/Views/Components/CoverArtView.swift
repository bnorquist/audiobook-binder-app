import SwiftUI

struct CoverArtView: View {
    let coverURL: URL?
    let onChoose: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let url = coverURL, let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 2)

                HStack(spacing: 8) {
                    Button("Change...") { onChoose() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("Remove", role: .destructive) { onRemove() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .frame(width: 150, height: 150)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "book.closed")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("No Cover")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                Button("Choose Image...") { onChoose() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}
