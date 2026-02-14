import SwiftUI

struct MetadataFormView: View {
    @Binding var metadata: BookMetadata

    var body: some View {
        Form {
            Section("Book Info") {
                TextField("Title", text: $metadata.title)
                TextField("Author", text: $metadata.author)
                TextField("Narrator", text: $metadata.narrator)
                TextField("Series", text: $metadata.series)
                TextField("Year", text: $metadata.year)
                TextField("Genre", text: $metadata.genre)
            }

            Section("Description") {
                TextEditor(text: $metadata.description)
                    .frame(minHeight: 60, maxHeight: 120)
                    .font(.body)
            }
        }
        .formStyle(.grouped)
    }
}
