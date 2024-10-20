import Foundation
import Lista
import TrailerJson
import TrailerQL

@MainActor
struct Org: Item {
    var id: String
    var parents: [String: Lista<Relationship>]
    var syncState = SyncState.none
    var elementType: String

    var name = ""

    static var allItems = [String: Org]()
    static let typeName = "Org"

    private enum CodingKeys: CodingKey {
        case id
        case name
        case parents
        case elementType
    }

    mutating func apply(_ node: TypedJson.Entry) -> Bool {
        guard ((try? node.keys)?.count ?? 0) > 1 else { return false }
        name = node.potentialString(named: "name") ?? ""
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

    static let fragmentWithRepos = Fragment(on: "Organization") {
        Field.id
        Field("name")
        Group("repositories", paging: .first(count: 100, paging: true)) { Repo.fragment }
    }
}
