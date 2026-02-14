import Foundation

struct BookMetadata: Equatable {
    var title: String = ""
    var author: String = ""
    var narrator: String = ""
    var series: String = ""
    var year: String = ""
    var genre: String = "Audiobook"
    var description: String = ""
    var coverPath: String? = nil
}
