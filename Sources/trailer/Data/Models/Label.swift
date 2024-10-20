import Foundation
import Lista
import TrailerJson
import TrailerQL

@MainActor
struct Label: Item {
    var id: String
    var parents: [String: Lista<Relationship>]
    var syncState = SyncState.none
    var elementType: String

    static var allItems = [String: Label]()
    static let typeName = "Label"

    var color = ""
    var name = ""

    private enum CodingKeys: CodingKey {
        case id
        case parents
        case elementType
        case name
        case color
    }

    mutating func apply(_ node: TypedJson.Entry) -> Bool {
        guard ((try? node.keys)?.count ?? 0) > 1 else { return false }
        name = node.potentialString(named: "name") ?? ""
        color = node.potentialString(named: "color") ?? ""
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

    var issue: Issue? {
        if let parentId = parents["Issue:labels"]?.first?.parentId {
            return Issue.allItems[parentId]
        }
        return nil
    }

    var pullRequest: PullRequest? {
        if let parentId = parents["PullRequest:labels"]?.first?.parentId {
            return PullRequest.allItems[parentId]
        }
        return nil
    }

    mutating func setChildrenSyncStatus(_: SyncState) {}

    static let fragment = Fragment(on: "Label") {
        Field.id
        Field("name")
        Field("color")
    }
}
