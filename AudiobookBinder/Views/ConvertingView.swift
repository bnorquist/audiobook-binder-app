import SwiftUI

struct ConvertingView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Converting...")
                .font(.title)

            VStack(spacing: 12) {
                ProgressView(value: viewModel.conversionProgress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 400)

                HStack {
                    Text("\(Int(viewModel.conversionProgress * 100))%")
                        .monospacedDigit()

                    Spacer()

                    Text(elapsedTimeString)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 400)
                .font(.callout)
            }

            Button("Cancel") {
                viewModel.cancelConversion()
            }
            .controlSize(.large)

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var elapsedTimeString: String {
        guard let start = viewModel.conversionStartTime else { return "" }
        let elapsed = Int(Date().timeIntervalSince(start))
        let elapsedStr = DurationFormatter.format(elapsed * 1000)

        if viewModel.conversionProgress > 0.01 {
            let totalEstimate = Double(elapsed) / viewModel.conversionProgress
            let remaining = Int(totalEstimate) - elapsed
            if remaining > 0 {
                return "\(elapsedStr) elapsed, ~\(DurationFormatter.format(remaining * 1000)) remaining"
            }
        }
        return "\(elapsedStr) elapsed"
    }
}
