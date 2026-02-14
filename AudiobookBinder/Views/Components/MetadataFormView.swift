import SwiftUI

struct MetadataFormView: View {
    @Binding var metadata: BookMetadata

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $metadata.title)
                TextField("Author", text: $metadata.author)
                TextField("Narrator", text: $metadata.narrator)
            } header: {
                Label("Book Info", systemImage: "book")
            }

            Section {
                TextField("Series", text: $metadata.series)
                TextField("Year", text: $metadata.year)
                TextField("Genre", text: $metadata.genre)
            } header: {
                Label("Details", systemImage: "info.circle")
            }

            Section {
                TextEditor(text: $metadata.description)
                    .frame(minHeight: 60, maxHeight: 120)
                    .font(.body)
            } header: {
                Label("Description", systemImage: "text.alignleft")
            }
        }
        .formStyle(.grouped)
    }
}
