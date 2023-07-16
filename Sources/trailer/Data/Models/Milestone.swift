import Foundation
import TrailerQL
import Lista

struct Milestone: Item {
    var id: String
    var parents: [String: Lista<Relationship>]
    var syncState = SyncState.none
    var elementType: String

    static var allItems = [String: Milestone]()
    static let idField = "id"
    static let typeName = "Milestone"

    var title = ""

    private enum CodingKeys: CodingKey {
        case id
        case parents
        case elementType
        case title
    }

    mutating func apply(_ node: JSON) -> Bool {
        guard node.keys.count > 1 else { return false }
        title = node["title"] as? String ?? ""
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

    mutating func setChildrenSyncStatus(_: SyncState) {}

    static let fragment = Fragment(on: "Milestone") {
        Field.id
        Field("title")
    }
}
