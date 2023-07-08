import Foundation

struct Org: Item {
    var id: String
    var parents: [String: LinkedList<Relationship>]
    var syncState = SyncState.none
    var elementType: String

    var name = ""

    static var allItems = [String: Org]()
    static let idField = "id"

    private enum CodingKeys: CodingKey {
        case id
        case name
        case parents
        case elementType
    }

    mutating func apply(_ node: JSON) -> Bool {
        guard node.keys.count > 1 else { return false }
        name = node["name"] as? String ?? ""
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

    mutating func setChildrenSyncStatus(_ status: SyncState) {
        for r in repos {
            var R = r
            R.setSyncStatus(status, andChildren: true)
            Repo.allItems[r.id] = R
        }
    }

    var repos: [Repo] {
        children(field: "repositories")
    }

    static let fragmentWithRepos = Fragment(name: "orgFieldsAndRepos", on: "Organization", elements: [
        Field.id,
        Field(name: "name"),
        Group(name: "repositories", fields: [Repo.fragment], paging: .largePage)
    ])
}
