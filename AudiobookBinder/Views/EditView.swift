import SwiftUI

struct EditView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                chapterList
                    .frame(minWidth: 300)

                rightPanel
                    .frame(minWidth: 280, idealWidth: 320)
            }

            Divider()
            bottomBar
        }
    }

    // MARK: - Chapter List

    private var chapterList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Chapters")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.chapters.count) files")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                Text("(\(viewModel.formattedTotalDuration))")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            List {
                ForEach(Array(viewModel.chapters.enumerated()), id: \.element.id) { index, chapter in
                    ChapterRowView(
                        chapter: chapter,
                        index: index,
                        onTitleChange: { newTitle in
                            viewModel.updateChapterTitle(id: chapter.id, newTitle: newTitle)
                        }
                    )
                }
                .onMove { source, destination in
                    viewModel.moveChapter(from: source, to: destination)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Cover Art
                CoverArtView(
                    coverURL: viewModel.coverImageURL,
                    onChoose: { viewModel.chooseCoverImage() },
                    onRemove: { viewModel.removeCoverImage() }
                )
                .padding(.top, 16)

                Divider()

                // Metadata Form
                MetadataFormView(metadata: $viewModel.metadata)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Button("Back") {
                viewModel.startOver()
            }

            Spacer()

            if let error = viewModel.conversionError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .lineLimit(2)
            }

            Button("Convert") {
                viewModel.startConversion()
            }
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
    }
}
