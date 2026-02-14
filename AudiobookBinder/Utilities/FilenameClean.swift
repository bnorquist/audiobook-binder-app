import Foundation

enum FilenameClean {
    /// Derive a chapter name from a filename.
    ///
    /// Strips numbering prefixes, underscores, and extensions.
    /// Examples:
    ///   "01_intro.mp3" → "Intro"
    ///   "03 - Chapter Three.mp3" → "Chapter Three"
    ///   "chapter_02.mp3" → "Chapter 02"
    static func chapterName(from filename: String) -> String {
        // Remove extension
        var name = (filename as NSString).deletingPathExtension

        // Strip leading numbers and separators like " - ", "_", "."
        if let range = name.range(of: #"^\d+[\s._-]*(?:-\s*)?"#, options: .regularExpression) {
            name = String(name[range.upperBound...])
        }

        // Replace underscores with spaces
        name = name.replacingOccurrences(of: "_", with: " ")
        name = name.trimmingCharacters(in: .whitespaces)

        // Title-case if it's all lowercase
        if name == name.lowercased() && !name.isEmpty {
            name = name.capitalized
        }

        return name.isEmpty ? filename : name
    }
}
