import AppKit
import Foundation
import Observation

enum AppState: Equatable {
    case importing
    case editing
    case converting
    case done
}

@Observable
final class AppViewModel {
    var appState: AppState = .importing
    var audioFiles: [AudioFile] = []
    var chapters: [Chapter] = []
    var metadata: BookMetadata = BookMetadata()
    var coverImageURL: URL? = nil

    // Import state
    var isProbing = false
    var probeProgress: Double = 0
    var importError: String? = nil

    // Conversion state
    var conversionProgress: Double = 0
    var conversionCurrentMs: Int = 0
    var conversionTotalMs: Int = 0
    var conversionStartTime: Date? = nil
    var conversionError: String? = nil
    var outputURL: URL? = nil
    var outputFileSize: Int64 = 0

    private var conversionTask: Task<Void, Never>? = nil

    // MARK: - Import

    func importFolder(url: URL) {
        importError = nil
        isProbing = true
        probeProgress = 0

        Task {
            do {
                let mp3URLs = try FileDiscoveryService.discoverMP3s(in: url)
                let files = try await FFProbeService.probeFiles(urls: mp3URLs)

                await MainActor.run {
                    self.audioFiles = files
                    self.chapters = MetadataService.buildChapters(from: files)
                    self.metadata = MetadataService.detectBookMetadata(from: files)
                    self.coverImageURL = FileDiscoveryService.findCoverImage(in: url)
                    if let cover = self.coverImageURL {
                        self.metadata.coverPath = cover.path
                    }
                    self.isProbing = false
                    self.appState = .editing
                }
            } catch {
                await MainActor.run {
                    self.importError = error.localizedDescription
                    self.isProbing = false
                }
            }
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder containing MP3 files"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        importFolder(url: url)
    }

    // MARK: - Edit

    func moveChapter(from source: IndexSet, to destination: Int) {
        chapters.move(fromOffsets: source, toOffset: destination)
        recalculateTimestamps()
    }

    func updateChapterTitle(id: UUID, newTitle: String) {
        guard let index = chapters.firstIndex(where: { $0.id == id }) else { return }
        chapters[index].title = newTitle
    }

    func chooseCoverImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.jpeg, .png]
        panel.message = "Choose a cover image"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        coverImageURL = url
        metadata.coverPath = url.path
    }

    func removeCoverImage() {
        coverImageURL = nil
        metadata.coverPath = nil
    }

    private func recalculateTimestamps() {
        var currentMs = 0
        for i in chapters.indices {
            let duration = chapters[i].durationMs
            chapters[i].startMs = currentMs
            chapters[i].endMs = currentMs + duration
            currentMs += duration
        }
    }

    // MARK: - Conversion

    func startConversion() {
        // Show save panel
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "m4b")!]
        panel.nameFieldStringValue = metadata.title.isEmpty ? "audiobook.m4b" : "\(metadata.title).m4b"
        panel.message = "Choose where to save the audiobook"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        outputURL = url

        let bitrate = MetadataService.determineBitrate(from: audioFiles)
        conversionProgress = 0
        conversionCurrentMs = 0
        conversionTotalMs = audioFiles.reduce(0) { $0 + $1.durationMs }
        conversionStartTime = Date()
        conversionError = nil
        appState = .converting

        conversionTask = Task {
            do {
                let stream = FFmpegService.convert(
                    audioFiles: audioFiles,
                    metadata: metadata,
                    chapters: chapters,
                    bitrate: bitrate,
                    coverPath: metadata.coverPath,
                    outputURL: url
                )

                for try await progress in stream {
                    await MainActor.run {
                        self.conversionProgress = progress.fraction
                        self.conversionCurrentMs = progress.currentMs
                    }
                }

                // Completed
                let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attrs?[.size] as? Int64 ?? 0

                await MainActor.run {
                    self.conversionProgress = 1.0
                    self.outputFileSize = fileSize
                    self.appState = .done
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.appState = .editing
                }
            } catch let error as AudiobookError where error.isCancellation {
                await MainActor.run {
                    self.appState = .editing
                }
            } catch {
                await MainActor.run {
                    self.conversionError = error.localizedDescription
                    self.appState = .editing
                }
            }
        }
    }

    func cancelConversion() {
        conversionTask?.cancel()
        conversionTask = nil
    }

    // MARK: - Done

    func revealInFinder() {
        guard let url = outputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func startOver() {
        audioFiles = []
        chapters = []
        metadata = BookMetadata()
        coverImageURL = nil
        conversionProgress = 0
        conversionCurrentMs = 0
        conversionTotalMs = 0
        conversionStartTime = nil
        conversionError = nil
        outputURL = nil
        outputFileSize = 0
        importError = nil
        appState = .importing
    }

    // MARK: - Computed

    var totalDurationMs: Int {
        chapters.reduce(0) { $0 + $1.durationMs }
    }

    var formattedTotalDuration: String {
        DurationFormatter.format(totalDurationMs)
    }
}
