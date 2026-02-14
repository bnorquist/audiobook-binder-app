import SwiftUI

struct DoneView: View {
    @Bindable var viewModel: AppViewModel
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: appeared)

            Text("Audiobook Created")
                .font(.title)

            VStack(spacing: 12) {
                if let url = viewModel.outputURL {
                    Label(url.lastPathComponent, systemImage: "doc.richtext")
                        .font(.headline)
                }

                Label(fileSizeString, systemImage: "internaldrive")
                    .foregroundStyle(.secondary)

                Label("Duration: \(viewModel.formattedTotalDuration)", systemImage: "clock")
                    .foregroundStyle(.secondary)

                Label("\(viewModel.chapters.count) chapters", systemImage: "list.number")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )

            HStack(spacing: 16) {
                Button {
                    viewModel.revealInFinder()
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    viewModel.startOver()
                } label: {
                    Label("Convert Another File", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }

    private var fileSizeString: String {
        let bytes = viewModel.outputFileSize
        let mb = Double(bytes) / (1024 * 1024)
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }
}
