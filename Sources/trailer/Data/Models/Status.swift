import Foundation
import TrailerQL

enum StatusState: String, Codable {
    case expected, error, failure, pending, success, empty, neutral, actionRequired, cancelled, skipped
    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "expected": self = .expected
        case "failure": self = .failure
        case "pending": self = .pending
        case "success": self = .success
        case "neutral": self = .neutral
        case "action_required": self = .actionRequired
        case "cancelled": self = .cancelled
        case "skipped": self = .skipped
        case "": self = .empty
        default:
            self = .error
        }
    }
}

struct Status: Item {
    var id: String
    var parents: [String: LinkedList<Relationship>]
    var syncState = SyncState.none
    var elementType: String

    static var allItems = [String: Status]()
    static let idField = "id"

    var context = ""
    var createdAt = Date.distantPast
    var description = ""
    var state = StatusState.expected
    var targetUrl = emptyURL

    private enum CodingKeys: CodingKey {
        case id
        case parents
        case elementType
        case context
        case createdAt
        case description
        case state
        case targetUrl
    }

    mutating func apply(_ node: JSON) -> Bool {
        guard node.keys.count > 6 else { return false }

        createdAt = GHDateFormatter.parseGH8601(node["createdAt"] as? String) ?? .distantPast
        targetUrl = URL(string: node["targetUrl"] as? String ?? "") ?? emptyURL

        if let nodeContext = node["context"] as? String {
            context = nodeContext
            state = StatusState(rawValue: node["state"] as? String ?? "EXPECTED") ?? .expected
            description = node["description"] as? String ?? ""
        } else {
            context = Notifications.Notification.formatter.string(from: createdAt)
            state = StatusState(rawValue: node["conclusion"] as? String ?? "EXPECTED") ?? .expected
            description = node["name"] as? String ?? ""
        }
        return true
    }

    var pullRequest: PullRequest? {
        if let parentId = parents["PullRequest:contexts"]?.first?.parentId {
            return PullRequest.allItems[parentId]
        }
        return nil
    }

    mutating func setChildrenSyncStatus(_: SyncState) {}

    init?(id: String, type: String, node: JSON) {
        self.id = id
        parents = [String: LinkedList<Relationship>]()
        elementType = type
        syncState = .new
        if !apply(node) {
            return nil
        }
    }

    static var fragmentForStatus = Fragment(on: "StatusContext") {
        TQL.idField
        Field("context")
        Field("description")
        Field("state")
        Field("targetUrl")
        Field("createdAt")
    }

    static let fragmentForCheck = Fragment(on: "CheckRun") {
        TQL.idField
        Field("name")
        Field("conclusion")
        Field("startedAt")
        Field("completedAt")
        Field("permalink")
    }
}
