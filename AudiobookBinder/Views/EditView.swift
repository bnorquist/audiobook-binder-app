import SwiftUI

struct EditView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        HSplitView {
            chapterList
                .frame(minWidth: 300)

            rightPanel
                .frame(minWidth: 280, idealWidth: 320)
        }
        .safeAreaInset(edge: .bottom) {
            if let error = viewModel.conversionError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.callout)
                        .lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Chapter List

    private var chapterList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Chapters", systemImage: "list.number")
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
            .background(.bar)

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
                CoverArtView(
                    coverURL: viewModel.coverImageURL,
                    onChoose: { viewModel.chooseCoverImage() },
                    onRemove: { viewModel.removeCoverImage() }
                )
                .padding(.top, 16)

                Divider()

                MetadataFormView(metadata: $viewModel.metadata)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }
}
