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

    /// Cached encoder result — detected once per app launch.
    private static let cachedEncoder: String = {
        let ffmpeg = BundledBinary.ffmpeg
        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = ["-encoders"]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

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
    }()

    /// Run the full ffmpeg conversion, streaming progress updates.
    static func convert(
        audioFiles: [AudioFile],
        metadata: BookMetadata,
        chapters: [Chapter],
        bitrate: Int,
        coverPath: String?,
        outputURL: URL
    ) -> AsyncThrowingStream<Progress, Error> {
        let totalMs = audioFiles.reduce(0) { $0 + $1.durationMs }
        let encoder = cachedEncoder

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
            "-v", "error",          // Suppress noisy stderr output
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
        process.qualityOfService = .userInitiated

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        // Drain stderr asynchronously to prevent pipe buffer filling up
        // and blocking ffmpeg. Capture for error reporting if needed.
        var stderrData = Data()
        let stderrLock = NSLock()
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                stderrLock.lock()
                stderrData.append(data)
                stderrLock.unlock()
            }
        }

        try process.run()

        // Parse progress from stdout
        let fileHandle = stdout.fileHandleForReading
        var leftover = ""
        var lastYieldedPercent = -1

        while true {
            if Task.isCancelled {
                process.terminate()
                process.waitUntilExit()
                stderr.fileHandleForReading.readabilityHandler = nil
                throw AudiobookError.conversionCancelled
            }

            let data = fileHandle.availableData
            guard !data.isEmpty else { break }  // EOF — process closed stdout

            let chunk = leftover + (String(data: data, encoding: .utf8) ?? "")
            let lines = chunk.components(separatedBy: "\n")
            leftover = lines.last ?? ""

            for line in lines.dropLast() {
                if line.hasPrefix("out_time_us=") {
                    let eqIdx = line.index(line.startIndex, offsetBy: 12)
                    if let timeUs = Int(line[eqIdx...]) {
                        let timeMs = timeUs / 1000
                        let pct = totalMs > 0 ? min(100, timeMs * 100 / totalMs) : 0
                        // Only yield on percentage change to reduce overhead
                        if pct != lastYieldedPercent {
                            lastYieldedPercent = pct
                            continuation.yield(Progress(currentMs: timeMs, totalMs: totalMs))
                        }
                    }
                }
            }
        }

        process.waitUntilExit()
        stderr.fileHandleForReading.readabilityHandler = nil

        guard process.terminationStatus == 0 else {
            stderrLock.lock()
            let errString = String(data: stderrData, encoding: .utf8) ?? "Unknown error"
            stderrLock.unlock()
            throw AudiobookError.ffmpegFailed(errString)
        }
    }
}
