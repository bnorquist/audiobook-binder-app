import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.appState {
                case .importing:
                    ImportView(viewModel: viewModel)
                        .transition(.opacity)
                case .editing:
                    EditView(viewModel: viewModel)
                        .transition(.opacity)
                case .converting:
                    ConvertingView(viewModel: viewModel)
                        .transition(.opacity)
                case .done:
                    DoneView(viewModel: viewModel)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.appState)
            .navigationTitle(navigationTitle)
            .toolbar {
                toolbarContent
            }
        }
    }

    private var navigationTitle: String {
        switch viewModel.appState {
        case .importing:
            return "Audiobook Binder"
        case .editing:
            return viewModel.metadata.title.isEmpty ? "Edit Audiobook" : viewModel.metadata.title
        case .converting:
            return "Converting..."
        case .done:
            return "Complete"
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        switch viewModel.appState {
        case .importing:
            ToolbarItem(placement: .automatic) {
                Color.clear.frame(width: 0, height: 0)
            }
        case .editing:
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") {
                    viewModel.startOver()
                }
                .buttonStyle(.bordered)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Convert") {
                    viewModel.startConversion()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
        case .converting:
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.cancelConversion()
                }
            }
        case .done:
            ToolbarItem(placement: .automatic) {
                Color.clear.frame(width: 0, height: 0)
            }
        }
    }
}
