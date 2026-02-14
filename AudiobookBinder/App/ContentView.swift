import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        Group {
            switch viewModel.appState {
            case .importing:
                ImportView(viewModel: viewModel)
            case .editing:
                EditView(viewModel: viewModel)
            case .converting:
                ConvertingView(viewModel: viewModel)
            case .done:
                DoneView(viewModel: viewModel)
            }
        }
        .animation(.default, value: viewModel.appState)
    }
}
