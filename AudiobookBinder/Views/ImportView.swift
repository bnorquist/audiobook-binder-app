import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Bindable var viewModel: AppViewModel
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if viewModel.isProbing {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Probing audio files...")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            } else {
                dropZone
            }

            if let error = viewModel.importError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dropZone: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)

            Text("Drop a folder of MP3 files here")
                .font(.title2)

            Text("or")
                .foregroundStyle(.tertiary)

            Button("Choose Folder...") {
                viewModel.chooseFolder()
            }
            .controlSize(.large)
        }
        .frame(maxWidth: 400, maxHeight: 300)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.hasDirectoryPath else { return }
            DispatchQueue.main.async {
                viewModel.importFolder(url: url)
            }
        }
        return true
    }
}
