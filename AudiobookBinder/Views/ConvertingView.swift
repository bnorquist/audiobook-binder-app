import SwiftUI

struct ConvertingView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .symbolEffect(.variableColor.iterative)

            Text("Converting to M4B")
                .font(.title)

            VStack(spacing: 16) {
                ProgressView(value: viewModel.conversionProgress)
                    .progressViewStyle(.linear)

                HStack {
                    Text("\(Int(viewModel.conversionProgress * 100))%")
                        .monospacedDigit()

                    Spacer()

                    Text(durationProgressString)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.callout)

                Text(elapsedTimeString)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            .padding(24)
            .frame(maxWidth: 420)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var durationProgressString: String {
        let current = DurationFormatter.format(viewModel.conversionCurrentMs)
        let total = DurationFormatter.format(viewModel.conversionTotalMs)
        return "\(current) of \(total)"
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
