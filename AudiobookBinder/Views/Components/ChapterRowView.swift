import SwiftUI

struct ChapterRowView: View {
    let chapter: Chapter
    let index: Int
    let onTitleChange: (String) -> Void

    @State private var editedTitle: String
    @FocusState private var isFocused: Bool

    init(chapter: Chapter, index: Int, onTitleChange: @escaping (String) -> Void) {
        self.chapter = chapter
        self.index = index
        self.onTitleChange = onTitleChange
        self._editedTitle = State(initialValue: chapter.title)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .font(.caption)

            Text("\(index + 1).")
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 30, alignment: .trailing)

            TextField("Chapter title", text: $editedTitle)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        onTitleChange(editedTitle)
                    }
                }
                .onSubmit {
                    onTitleChange(editedTitle)
                }

            Spacer()

            Text(DurationFormatter.format(chapter.durationMs))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .font(.callout)
        }
        .padding(.vertical, 4)
    }
}
