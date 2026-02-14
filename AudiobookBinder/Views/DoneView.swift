import SwiftUI

struct DoneView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Conversion Complete")
                .font(.title)

            VStack(spacing: 8) {
                if let url = viewModel.outputURL {
                    Text(url.lastPathComponent)
                        .font(.headline)
                }

                Text(fileSizeString)
                    .foregroundStyle(.secondary)

                Text("Duration: \(viewModel.formattedTotalDuration)")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Button("Reveal in Finder") {
                    viewModel.revealInFinder()
                }
                .controlSize(.large)

                Button("Convert Another") {
                    viewModel.startOver()
                }
                .controlSize(.large)
            }

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
