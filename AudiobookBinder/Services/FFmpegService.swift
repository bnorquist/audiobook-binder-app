import Foundation

enum FFmpegService {
    struct Progress {
        let currentMs: Int
        let totalMs: Int
        var fraction: Double {
            guard totalMs > 0 else { return 0 }
            return min(1.0, Double(currentMs) / Double(totalMs))
        }
        var percent: Int { Int(fraction * 100) }
    }

    /// Check if the aac_at (Apple AudioToolbox) encoder is available.
    static func detectEncoder() -> String {
        let ffmpeg = BundledBinary.ffmpeg
        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = ["-encoders"]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            if output.contains("aac_at") {
                return "aac_at"
            }
        } catch {}

        return "aac"
    }

    /// Run the full ffmpeg conversion, streaming progress updates.
    ///
    /// Returns an `AsyncStream<Progress>` that yields progress updates.
    /// The stream completes when conversion finishes or is cancelled.
    static func convert(
        audioFiles: [AudioFile],
        metadata: BookMetadata,
        chapters: [Chapter],
        bitrate: Int,
        coverPath: String?,
        outputURL: URL,
        task: Task<Void, Never>? = nil
    ) -> AsyncThrowingStream<Progress, Error> {
        let totalMs = audioFiles.reduce(0) { $0 + $1.durationMs }
        let encoder = detectEncoder()

        return AsyncThrowingStream { continuation in
            let workItem = DispatchWorkItem {
                do {
                    try runFFmpeg(
                        audioFiles: audioFiles,
                        metadata: metadata,
                        chapters: chapters,
                        bitrate: bitrate,
                        encoder: encoder,
                        coverPath: coverPath,
                        outputURL: outputURL,
                        totalMs: totalMs,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                workItem.cancel()
            }

            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
        }
    }

    // MARK: - Private

    private static func runFFmpeg(
        audioFiles: [AudioFile],
        metadata: BookMetadata,
        chapters: [Chapter],
        bitrate: Int,
        encoder: String,
        coverPath: String?,
        outputURL: URL,
        totalMs: Int,
        continuation: AsyncThrowingStream<Progress, Error>.Continuation
    ) throws {
        let ffmpeg = BundledBinary.ffmpeg
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("audiobook_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tmpDir)
        }

        // Write concat file
        let concatURL = tmpDir.appendingPathComponent("filelist.txt")
        let concatContent = audioFiles.map { af in
            let escaped = af.path.replacingOccurrences(of: "'", with: "'\\''")
            return "file '\(escaped)'"
        }.joined(separator: "\n")
        try concatContent.write(to: concatURL, atomically: true, encoding: .utf8)

        // Write metadata file
        let metaURL = tmpDir.appendingPathComponent("metadata.txt")
        let metaContent = FFMetadataWriter.generate(metadata: metadata, chapters: chapters)
        try metaContent.write(to: metaURL, atomically: true, encoding: .utf8)

        // Build ffmpeg command
        var args = [
            "-f", "concat",
            "-safe", "0",
            "-i", concatURL.path,
            "-i", metaURL.path,
        ]

        let hasCover = coverPath != nil && FileManager.default.fileExists(atPath: coverPath!)
        if hasCover {
            args += ["-i", coverPath!]
            args += ["-map", "0:a", "-map", "2:v"]
            args += ["-c:v", "copy", "-disposition:v", "attached_pic"]
        } else {
            args += ["-map", "0:a"]
        }

        args += [
            "-c:a", encoder,
            "-b:a", "\(bitrate)k",
            "-ar", "44100",
            "-threads", "0",
            "-map_metadata", "1",
            "-map_chapters", "1",
            "-progress", "pipe:1",
            "-nostats",
            "-y", outputURL.path,
        ]

        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = args

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()

        // Parse progress from stdout
        let fileHandle = stdout.fileHandleForReading
        var leftover = ""

        while process.isRunning {
            if Task.isCancelled {
                process.terminate()
                throw AudiobookError.conversionCancelled
            }

            let data = fileHandle.availableData
            guard !data.isEmpty else { break }

            let chunk = leftover + (String(data: data, encoding: .utf8) ?? "")
            let lines = chunk.components(separatedBy: "\n")
            leftover = lines.last ?? ""

            for line in lines.dropLast() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("out_time_us=") {
                    if let valueStr = trimmed.split(separator: "=").last,
                       let timeUs = Int(valueStr) {
                        let timeMs = timeUs / 1000
                        continuation.yield(Progress(currentMs: timeMs, totalMs: totalMs))
                    }
                }
            }
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errString = String(data: errData, encoding: .utf8) ?? "Unknown error"
            throw AudiobookError.ffmpegFailed(errString)
        }
    }
}
