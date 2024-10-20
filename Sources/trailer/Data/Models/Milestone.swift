import Foundation
import Lista
import TrailerJson
import TrailerQL

@MainActor
struct Milestone: Item {
    var id: String
    var parents: [String: Lista<Relationship>]
    var syncState = SyncState.none
    var elementType: String

    static var allItems = [String: Milestone]()
    static let typeName = "Milestone"

    var title = ""

    private enum CodingKeys: CodingKey {
        case id
        case parents
        case elementType
        case title
    }

    mutating func apply(_ node: TypedJson.Entry) -> Bool {
        guard ((try? node.keys)?.count ?? 0) > 1 else { return false }
        title = node.potentialString(named: "title") ?? ""
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

    static let fragment = Fragment(on: "Milestone") {
        Field.id
        Field("title")
    }
}
