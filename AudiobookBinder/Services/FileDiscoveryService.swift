import Foundation

enum FileDiscoveryService {
    /// Find all MP3 files in a directory, natural-sorted by filename (Finder order).
    static func discoverMP3s(in directoryURL: URL) throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        let mp3s = contents
            .filter { $0.pathExtension.lowercased() == "mp3" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        guard !mp3s.isEmpty else {
            throw AudiobookError.noMP3Files
        }
        return mp3s
    }

    /// Find the first image file (jpg/jpeg/png) in the directory.
    static func findCoverImage(in directoryURL: URL) -> URL? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let imageExtensions: Set<String> = ["jpg", "jpeg", "png"]
        return contents
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .first
    }
}

enum AudiobookError: LocalizedError {
    case noMP3Files
    case ffprobeNotFound
    case ffmpegNotFound
    case ffprobeFailed(String)
    case ffmpegFailed(String)
    case conversionCancelled

    var isCancellation: Bool {
        if case .conversionCancelled = self { return true }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .noMP3Files:
            return "No MP3 files found in the selected folder."
        case .ffprobeNotFound:
            return "ffprobe not found in app bundle. Place the static binary in Resources/."
        case .ffmpegNotFound:
            return "ffmpeg not found in app bundle. Place the static binary in Resources/."
        case .ffprobeFailed(let msg):
            return "ffprobe failed: \(msg)"
        case .ffmpegFailed(let msg):
            return "ffmpeg failed: \(msg)"
        case .conversionCancelled:
            return "Conversion was cancelled."
        }
    }
}
