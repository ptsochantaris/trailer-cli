import Foundation

enum ItemState: String, Codable {
    case open, closed, merged
    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "open": self = .open
        case "closed": self = .closed
        case "merged": self = .merged
        default: return nil
        }
    }
}
