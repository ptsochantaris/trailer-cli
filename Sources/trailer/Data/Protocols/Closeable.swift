import Foundation

protocol Closeable {
    var shouldAnnounceClosure: Bool { get }
    func announceClosure()
}
