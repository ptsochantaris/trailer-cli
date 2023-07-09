import Foundation
import TrailerQL
import Lista

struct Reaction: Item {
    var id: String
    var parents: [String: Lista<Relationship>]
    var syncState = SyncState.none
    var elementType: String

    var content = ""
    static let idField = "id"

    static var allItems = [String: Reaction]()

    private enum CodingKeys: CodingKey {
        case id
        case parents
        case elementType
        case content
    }

    mutating func apply(_ node: JSON) -> Bool {
        guard node.keys.count >= 1 else { return false }
        content = node["content"] as? String ?? ""
        return true
    }

    init?(id: String, type: String, node: JSON) {
        self.id = id
        parents = [String: Lista<Relationship>]()
        elementType = type
        syncState = .new
        if !apply(node) {
            return nil
        }
    }

    var user: User? {
        children(field: "user").first
    }

    mutating func setChildrenSyncStatus(_ status: SyncState) {
        if var u = user {
            u.setSyncStatus(status, andChildren: true)
            User.allItems[u.id] = u
        }
    }

    var emoji: String {
        switch content {
        case "THUMBS_UP": return "👍"
        case "THUMBS_DOWN": return "👎"
        case "LAUGH": return "😄"
        case "HOORAY": return "🎉"
        case "CONFUSED": return "😕"
        case "HEART": return "❤️"
        case "ROCKET": return "🚀"
        default:
            return "?"
        }
    }

    static let fragment = Fragment(on: "Reaction") {
        TQL.idField
        Field("content")
        Group("user") {
            User.fragment
        }
    }
}
