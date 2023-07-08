import Foundation

struct Milestone: Item {
    var id: String
    var parents: [String: LinkedList<Relationship>]
    var syncState = SyncState.none
    var elementType: String

    static var allItems = [String: Milestone]()
    static let idField = "id"

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
        parents = [String: LinkedList<Relationship>]()
        elementType = type
        syncState = .new
        if !apply(node) {
            return nil
        }
    }

    mutating func setChildrenSyncStatus(_: SyncState) {}

    static let fragment = Fragment(name: "milestoneFields", on: "Milestone", elements: [
        Field.id,
        Field(name: "title")
    ])
}
