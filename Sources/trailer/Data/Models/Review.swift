import Foundation

enum ReviewState: String, Codable {
    case pending, commented, approved, changes_requested, dismissed
    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "commented": self = ReviewState.commented
        case "approved": self = ReviewState.approved
        case "changes_requested": self = ReviewState.changes_requested
        case "dimissed", "dismissed": self = ReviewState.dismissed
        default: self = ReviewState.pending
        }
    }
}

struct Review: Item, Announceable {
    var id: String
    var parents: [String: LinkedList<Relationship>]
    var syncState = SyncState.none
    var elementType: String

    static var allItems = [String: Review]()
    static let idField = "id"

    var state = ReviewState.pending
    var body = ""
    var viewerDidAuthor = false
    var createdAt = Date.distantPast
    var updatedAt = Date.distantPast

    var syncNeedsComments = false

    var comments: [Comment] {
        children(field: "comments")
    }

    private enum CodingKeys: CodingKey {
        case id
        case parents
        case elementType
        case state
        case body
        case viewerDidAuthor
        case createdAt
        case updatedAt
    }

    mutating func apply(_ node: JSON) -> Bool {
        guard node.keys.count > 5 else { return false }

        syncNeedsComments = (node["comments"] as? JSON)?["totalCount"] as? Int ?? 0 > 0

        state = ReviewState(rawValue: node["state"] as? String ?? "PENDING")
        body = node["body"] as? String ?? ""
        createdAt = GHDateFormatter.parseGH8601(node["createdAt"] as? String) ?? Date.distantPast
        updatedAt = GHDateFormatter.parseGH8601(node["updatedAt"] as? String) ?? Date.distantPast
        viewerDidAuthor = node["viewerDidAuthor"] as? Bool ?? false
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

    func announceIfNeeded(notificationMode: NotificationMode) {
        if notificationMode != .consoleCommentsAndReviews || syncState != .new { return }
        if viewerDidAuthor { return }

        if let p = pullRequest, p.syncState != .new, let re = pullRequest?.repo, let a = p.author?.login, re.syncState != .new {
            let r = re.nameWithOwner
            let d: String
            switch state {
            case .approved:
                d = "[\(r)] @\(a) reviewed [G*(approving)*]"
            case .changes_requested:
                d = "[\(r)] @\(a) reviewed [R*(requesting changes)*]"
            case .commented where body.hasItems:
                d = "[\(r)] @\(a) reviewed"
            default:
                return
            }
            Notifications.notify(title: d, subtitle: "PR #\(p.number) \(p.title))", details: body, relatedDate: createdAt)
        }
    }

    private func printHeader() {
        if let a = author?.login {
            switch state {
            case .approved:
                log("[![*@\(a)*] \(agoFormat(prefix: "[G*Approved Changes*] ", since: createdAt))!]")
            case .changes_requested:
                log("[![*@\(a)*] \(agoFormat(prefix: "[R*Requested Changes*] ", since: createdAt))!]")
            default:
                log("[![*@\(a)*] \(agoFormat(prefix: "Reviewed ", since: createdAt))!]")
            }
        }
    }

    func printDetails() {
        printHeader()
        if body.hasItems {
            log(body.trimmingCharacters(in: .whitespacesAndNewlines), unformatted: true)
            log()
        }
    }

    var pullRequest: PullRequest? {
        if let parentId = parents["PullRequest:reviews"]?.first?.parentId {
            return PullRequest.allItems[parentId]
        }
        return nil
    }

    var author: User? {
        children(field: "author").first
    }

    mutating func setChildrenSyncStatus(_ status: SyncState) {
        if var u = author {
            u.setSyncStatus(status, andChildren: true)
            User.allItems[u.id] = u
        }
        for c in comments {
            var C = c
            C.setSyncStatus(status, andChildren: true)
            Comment.allItems[c.id] = C
        }
    }

    var mentionsMe: Bool {
        if body.localizedCaseInsensitiveContains(config.myLogin) {
            return true
        }
        return comments.contains { $0.mentionsMe }
    }

    func includes(text: String) -> Bool {
        if body.localizedCaseInsensitiveContains(text) { return true }
        return comments.contains { $0.includes(text: text) }
    }

    static let fragment = Fragment(name: "reviewFields", on: "PullRequestReview", elements: [
        Field.id,
        Field(name: "body"),
        Field(name: "state"),
        Field(name: "viewerDidAuthor"),
        Field(name: "createdAt"),
        Field(name: "updatedAt"),
        Group(name: "author", fields: [User.fragment]),
        Group(name: "comments", fields: [Field(name: "totalCount")])
    ])

    static let commentsFragment = Fragment(name: "ReviewCommentsFragment", on: "PullRequestReview", elements: [
        Field.id, // not using fragment, no need to re-parse
        Group(name: "comments", fields: [Comment.fragmentForReviews], paging: .largePage)
    ])
}
