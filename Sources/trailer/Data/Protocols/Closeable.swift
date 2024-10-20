import Foundation

@MainActor
protocol Closeable {
    var shouldAnnounceClosure: Bool { get }
    func announceClosure()
}
