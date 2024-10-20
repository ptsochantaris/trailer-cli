import Foundation
import Lista
import TrailerJson
import TrailerQL

struct User: Item {
    var id: String
    var parents: [String: Lista<Relationship>]
    var syncState = SyncState.none
    var elementType: String

    var avatarUrl = emptyURL
    var login = ""
    var isMe = false

    static var allItems = [String: User]()
    static let typeName = "User"

    private enum CodingKeys: CodingKey {
        case id
        case login
        case parents
        case elementType
        case avatarUrl
        case isMe
    }

    mutating func apply(_ node: TypedJson.Entry) -> Bool {
        guard ((try? node.keys)?.count ?? 0) > 2 else { return false }
        avatarUrl = URL(string: node.potentialString(named: "avatarUrl") ?? "") ?? emptyURL
        login = node.potentialString(named: "login") ?? ""
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

    mutating func setChildrenSyncStatus(_: SyncState) {}

    static let fragment = Fragment(on: "User") {
        Field.id
        Field("login")
        Field("avatarUrl")
    }
}
