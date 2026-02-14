import Foundation

enum FFProbeService {
    /// Probe a single MP3 file with ffprobe and return an AudioFile.
    static func probeFile(at url: URL) async throws -> AudioFile {
        let ffprobe = BundledBinary.ffprobe

        let process = Process()
        process.executableURL = ffprobe
        process.arguments = [
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            url.path,
        ]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errString = String(data: errData, encoding: .utf8) ?? "Unknown error"
            throw AudiobookError.ffprobeFailed(errString)
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return try parseProbeOutput(data: data, fileURL: url)
    }

    /// Probe multiple files in parallel using a TaskGroup (max 8 concurrent).
    static func probeFiles(urls: [URL]) async throws -> [AudioFile] {
        let maxConcurrency = min(8, urls.count)

        return try await withThrowingTaskGroup(of: (Int, AudioFile).self) { group in
            var results = [(Int, AudioFile)]()
            results.reserveCapacity(urls.count)
            var nextIndex = 0

            // Seed the group with initial tasks
            for _ in 0..<maxConcurrency where nextIndex < urls.count {
                let index = nextIndex
                let url = urls[index]
                nextIndex += 1
                group.addTask {
                    let file = try await probeFile(at: url)
                    return (index, file)
                }
            }

            // As each completes, add the next
            for try await result in group {
                results.append(result)
                if nextIndex < urls.count {
                    let index = nextIndex
                    let url = urls[index]
                    nextIndex += 1
                    group.addTask {
                        let file = try await probeFile(at: url)
                        return (index, file)
                    }
                }
            }

            // Sort by original index to preserve input order
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    // MARK: - JSON Parsing

    private static func parseProbeOutput(data: Data, fileURL: URL) throws -> AudioFile {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AudiobookError.ffprobeFailed("Invalid JSON from ffprobe")
        }

        let format = json["format"] as? [String: Any] ?? [:]
        let streams = json["streams"] as? [[String: Any]] ?? []

        // Find the audio stream
        let audioStream = streams.first { ($0["codec_type"] as? String) == "audio" }

        // Duration
        let durationStr = format["duration"] as? String ?? "0"
        let durationS = Double(durationStr) ?? 0
        let durationMs = Int(durationS * 1000)

        // Bitrate: prefer format-level, fall back to stream-level
        let bitrateStr = (format["bit_rate"] as? String)
            ?? (audioStream?["bit_rate"] as? String)
            ?? "0"
        let bitrateKbps = (Int(bitrateStr) ?? 0) / 1000

        // Sample rate
        let sampleRateStr = audioStream?["sample_rate"] as? String ?? "44100"
        let sampleRate = Int(sampleRateStr) ?? 44100

        // Tags (lowercase keys)
        let rawTags = format["tags"] as? [String: Any] ?? [:]
        var tags = [String: String]()
        for (key, value) in rawTags {
            tags[key.lowercased()] = "\(value)"
        }

        return AudioFile(
            path: fileURL.path,
            filename: fileURL.lastPathComponent,
            durationMs: durationMs,
            bitrate: bitrateKbps,
            sampleRate: sampleRate,
            tags: tags
        )
    }
}
