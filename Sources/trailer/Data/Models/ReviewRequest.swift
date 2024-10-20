import Foundation
import Lista
import TrailerJson
import TrailerQL

@MainActor
struct ReviewRequest: Item {
    var id: String
    var parents: [String: Lista<Relationship>]
    var syncState = SyncState.none
    var elementType: String

    static var allItems = [String: ReviewRequest]()
    static let typeName = "ReviewRequest"

    private enum CodingKeys: CodingKey {
        case id
        case parents
        case elementType
    }

    mutating func apply(_: TypedJson.Entry) -> Bool {
        true
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
        if var u = reviewer {
            u.setSyncStatus(status, andChildren: true)
            User.allItems[u.id] = u
        }
    }

    var reviewer: User? {
        let c: [User] = children(field: "requestedReviewer")
        return c.first
    }

    var pullRequest: PullRequest? {
        if let parentId = parents["PullRequest:reviewRequests"]?.first?.parentId {
            return PullRequest.allItems[parentId]
        }
        return nil
    }

    static let fragment = Fragment(on: "ReviewRequest") {
        Field.id
        Group("requestedReviewer") { User.fragment }
    }
}
