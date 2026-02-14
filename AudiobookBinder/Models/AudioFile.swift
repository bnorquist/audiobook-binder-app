import Foundation

struct AudioFile: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let filename: String
    let durationMs: Int
    let bitrate: Int       // kbps
    let sampleRate: Int
    let tags: [String: String]
}
