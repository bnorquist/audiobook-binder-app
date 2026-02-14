import Foundation

enum BundledBinary {
    static func url(for name: String) -> URL {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil) else {
            fatalError("\(name) not found in app bundle. Place the static binary in Resources/.")
        }
        return url
    }

    static var ffmpeg: URL { url(for: "ffmpeg") }
    static var ffprobe: URL { url(for: "ffprobe") }
}
