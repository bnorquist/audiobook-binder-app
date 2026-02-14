import Foundation

enum FFMetadataWriter {
    /// Generate FFMETADATA1 content for ffmpeg.
    static func generate(metadata: BookMetadata, chapters: [Chapter]) -> String {
        var lines = [";FFMETADATA1"]

        if !metadata.title.isEmpty {
            lines.append("title=\(escape(metadata.title))")
        }
        if !metadata.author.isEmpty {
            lines.append("artist=\(escape(metadata.author))")
        }
        if !metadata.title.isEmpty {
            lines.append("album=\(escape(metadata.title))")
        }
        if !metadata.genre.isEmpty {
            lines.append("genre=\(escape(metadata.genre))")
        }
        if !metadata.narrator.isEmpty {
            lines.append("composer=\(escape(metadata.narrator))")
        }
        if !metadata.year.isEmpty {
            lines.append("date=\(escape(metadata.year))")
        }
        if !metadata.description.isEmpty {
            lines.append("description=\(escape(metadata.description))")
        }

        for ch in chapters {
            lines.append("")
            lines.append("[CHAPTER]")
            lines.append("TIMEBASE=1/1000")
            lines.append("START=\(ch.startMs)")
            lines.append("END=\(ch.endMs)")
            lines.append("title=\(escape(ch.title))")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    /// Escape special characters for FFMETADATA format.
    private static func escape(_ value: String) -> String {
        var s = value
        s = s.replacingOccurrences(of: "\\", with: "\\\\")
        s = s.replacingOccurrences(of: "=", with: "\\=")
        s = s.replacingOccurrences(of: ";", with: "\\;")
        s = s.replacingOccurrences(of: "#", with: "\\#")
        s = s.replacingOccurrences(of: "\n", with: "\\\n")
        return s
    }
}
