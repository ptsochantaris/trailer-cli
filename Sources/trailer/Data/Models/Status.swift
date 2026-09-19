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

struct Status: @MainActor Item {
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
    var targetUrl = Config.emptyURL

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
        // Null fields are absent from the parsed keys, so a check run that has started but not
        // finished (or vice versa) arrives with six rather than seven. A placeholder node only
        // ever carries `__typename` and `id`, so this still rejects those.
        guard ((try? node.keys)?.count ?? 0) > 5 else { return false }

        if let nodeContext = node.potentialString(named: "context") {
            // A StatusContext: it carries `createdAt`, `targetUrl` and `state` directly.
            createdAt = GHDateFormatter.parseGH8601(node.potentialString(named: "createdAt")) ?? .distantPast
            targetUrl = URL(string: node.potentialString(named: "targetUrl") ?? "") ?? Config.emptyURL
            context = nodeContext
            state = StatusState(rawValue: node.potentialString(named: "state") ?? "EXPECTED") ?? .expected
            description = node.potentialString(named: "description") ?? ""
        } else {
            // A CheckRun: the equivalent fields are named `startedAt`/`completedAt` and `permalink`.
            createdAt = GHDateFormatter.parseGH8601(node.potentialString(named: "startedAt"))
                ?? GHDateFormatter.parseGH8601(node.potentialString(named: "completedAt"))
                ?? .distantPast
            targetUrl = URL(string: node.potentialString(named: "permalink") ?? "") ?? Config.emptyURL
            context = createdAt == .distantPast ? "" : createdAt.formatted(Notifications.Notification.timestampStyle)
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

    nonisolated static let fragmentForStatus = Fragment(on: "StatusContext") {
        Field.id
        Field("context")
        Field("description")
        Field("state")
        Field("targetUrl")
        Field("createdAt")
    }

    nonisolated static let fragmentForCheck = Fragment(on: "CheckRun") {
        Field.id
        Field("name")
        Field("conclusion")
        Field("startedAt")
        Field("completedAt")
        Field("permalink")
    }
}
