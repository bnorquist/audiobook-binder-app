import Foundation

struct Chapter: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var startMs: Int
    var endMs: Int
    let sourceFile: String

    var durationMs: Int { endMs - startMs }
}
