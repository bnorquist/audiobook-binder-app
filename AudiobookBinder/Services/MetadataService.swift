import Foundation

enum MetadataService {
    /// Resolve the chapter name for an audio file.
    /// Priority: ID3 title tag > cleaned filename.
    static func resolveChapterName(for audioFile: AudioFile) -> String {
        if let title = audioFile.tags["title"], !title.trimmingCharacters(in: .whitespaces).isEmpty {
            return title.trimmingCharacters(in: .whitespaces)
        }
        return FilenameClean.chapterName(from: audioFile.filename)
    }

    /// Build chapter list with cumulative timestamps from ordered audio files.
    static func buildChapters(from audioFiles: [AudioFile]) -> [Chapter] {
        var chapters = [Chapter]()
        var currentMs = 0

        for af in audioFiles {
            let title = resolveChapterName(for: af)
            let chapter = Chapter(
                title: title,
                startMs: currentMs,
                endMs: currentMs + af.durationMs,
                sourceFile: af.filename
            )
            chapters.append(chapter)
            currentMs += af.durationMs
        }

        return chapters
    }

    /// Auto-detect book metadata from consistent ID3 tags across files.
    static func detectBookMetadata(from audioFiles: [AudioFile]) -> BookMetadata {
        guard !audioFiles.isEmpty else { return BookMetadata() }

        let allTags = audioFiles.map(\.tags)

        func consistentTag(_ key: String) -> String {
            let values = Set(allTags.compactMap { tags -> String? in
                guard let v = tags[key]?.trimmingCharacters(in: .whitespaces), !v.isEmpty else { return nil }
                return v
            })
            return values.count == 1 ? values.first! : ""
        }

        let author = consistentTag("artist").isEmpty ? consistentTag("album_artist") : consistentTag("artist")

        return BookMetadata(
            title: consistentTag("album"),
            author: author,
            narrator: consistentTag("composer"),
            year: consistentTag("date").isEmpty ? consistentTag("year") : consistentTag("date"),
            genre: consistentTag("genre").isEmpty ? "Audiobook" : consistentTag("genre")
        )
    }

    /// Determine output bitrate from input files.
    /// Uses the max input bitrate, floored at 64kbps, capped at 256kbps.
    static func determineBitrate(from audioFiles: [AudioFile]) -> Int {
        let maxBitrate = audioFiles.map(\.bitrate).max() ?? 128
        return max(64, min(256, maxBitrate))
    }
}
