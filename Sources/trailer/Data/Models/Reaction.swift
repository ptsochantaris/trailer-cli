import Foundation
import Lista
import TrailerJson
import TrailerQL

@MainActor
struct Reaction: Item {
    var id: String
    var parents: [String: Lista<Relationship>]
    var syncState = SyncState.none
    var elementType: String

    var content = ""
    static let typeName = "Reaction"

    static var allItems = [String: Reaction]()

    private enum CodingKeys: CodingKey {
        case id
        case parents
        case elementType
        case content
    }

    mutating func apply(_ node: TypedJson.Entry) -> Bool {
        guard ((try? node.keys)?.count ?? 0) >= 1 else { return false }
        content = node.potentialString(named: "content") ?? ""
        return true
    }

    init?(id: String, type: String, node: TypedJson.Entry) {
        self.id = id
        parents = [String: Lista<Relationship>]()
        elementType = type
        syncState = .new
        if !apply(node) {
            return nil
        }
    }

    var user: User? {
        let c: [User] = children(field: "user")
        return c.first
    }

    mutating func setChildrenSyncStatus(_ status: SyncState) {
        if var u = user {
            u.setSyncStatus(status, andChildren: true)
            User.allItems[u.id] = u
        }
    }

    var emoji: String {
        switch content {
        case "THUMBS_UP": "👍"
        case "THUMBS_DOWN": "👎"
        case "LAUGH": "😄"
        case "HOORAY": "🎉"
        case "CONFUSED": "😕"
        case "HEART": "❤️"
        case "ROCKET": "🚀"
        default:
            "?"
        }
    }

    static let fragment = Fragment(on: "Reaction") {
        Field.id
        Field("content")
        Group("user") {
            User.fragment
        }
    }
}
