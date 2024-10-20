import Foundation
import Lista
import TrailerJson
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
    var parents: [String: Lista<Relationship>]
    var syncState = SyncState.none
    var elementType: String

    static var allItems = [String: Status]()
    static let typeName = "Status"

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

    mutating func apply(_ node: TypedJson.Entry) -> Bool {
        guard ((try? node.keys)?.count ?? 0) > 6 else { return false }

        createdAt = GHDateFormatter.parseGH8601(node.potentialString(named: "createdAt")) ?? .distantPast
        targetUrl = URL(string: node.potentialString(named: "targetUrl") ?? "") ?? emptyURL

        if let nodeContext = node.potentialString(named: "context") {
            context = nodeContext
            state = StatusState(rawValue: node.potentialString(named: "state") ?? "EXPECTED") ?? .expected
            description = node.potentialString(named: "description") ?? ""
        } else {
            context = Notifications.Notification.formatter.string(from: createdAt)
            state = StatusState(rawValue: node.potentialString(named: "conclusion") ?? "EXPECTED") ?? .expected
            description = node.potentialString(named: "name") ?? ""
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

    init?(id: String, type: String, node: TypedJson.Entry) {
        self.id = id
        parents = [String: Lista<Relationship>]()
        elementType = type
        syncState = .new
        if !apply(node) {
            return nil
        }
    }

    static var fragmentForStatus = Fragment(on: "StatusContext") {
        Field.id
        Field("context")
        Field("description")
        Field("state")
        Field("targetUrl")
        Field("createdAt")
    }

    static let fragmentForCheck = Fragment(on: "CheckRun") {
        Field.id
        Field("name")
        Field("conclusion")
        Field("startedAt")
        Field("completedAt")
        Field("permalink")
    }
}
