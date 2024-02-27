import Foundation
import Lista
import TrailerQL

struct Comment: Item, Announceable {
    var id: String
    var parents: [String: Lista<Relationship>]
    var syncState = SyncState.none
    var elementType: String

    static var allItems = [String: Comment]()
    static let typeName = "Comment"

    var syncNeedsReactions = false

    var body = ""
    var viewerDidAuthor = false
    var createdAt = Date.distantPast
    var updatedAt = Date.distantPast

    private enum CodingKeys: CodingKey {
        case id
        case parents
        case elementType
        case body
        case viewerDidAuthor
        case createdAt
        case updatedAt
    }

    mutating func apply(_ node: JSON) -> Bool {
        guard node.keys.count > 5 else { return false }

        syncNeedsReactions = (node["reactions"] as? JSON)?["totalCount"] as? Int ?? 0 > 0
        body = node["body"] as? String ?? ""
        viewerDidAuthor = node["viewerDidAuthor"] as? Bool ?? false
        createdAt = GHDateFormatter.parseGH8601(node["createdAt"] as? String) ?? Date.distantPast
        updatedAt = GHDateFormatter.parseGH8601(node["updatedAt"] as? String) ?? Date.distantPast
        return true
    }

    init?(id: String, type: String, node: JSON) {
        self.id = id
        syncState = .new
        parents = [String: Lista<Relationship>]()
        elementType = type
        if !apply(node) {
            return nil
        }
    }

    func announceIfNeeded(notificationMode: NotificationMode) {
        if viewerDidAuthor { return }

        if syncState == .new {
            switch notificationMode {
            case .consoleCommentsAndReviews:
                let a = author?.login ?? ""
                let n: Int
                let t: String
                let r: String
                let inReview: Bool
                let inPr: Bool
                if let p = pullRequest, let re = p.repo, re.syncState != .new {
                    n = p.number; t = p.title; r = re.nameWithOwner
                    inReview = false
                    inPr = true
                } else if let i = issue, let re = i.repo, re.syncState != .new {
                    n = i.number; t = i.title; r = re.nameWithOwner
                    inReview = false
                    inPr = false
                } else if let rv = review, let p = rv.pullRequest, let re = p.repo, re.syncState != .new {
                    n = p.number; t = p.title; r = re.nameWithOwner
                    inReview = true
                    inPr = false
                } else {
                    return
                }
                let title = "[\(r)] @\(a) commented" + (inReview ? " [*(in review)*]" : "")
                let subtitle = (inPr ? "PR" : "Issue") + " #\(n) \(t)"
                Notifications.notify(title: title, subtitle: subtitle, details: body, relatedDate: createdAt)

            case .none, .standard:
                return
            }
        }
    }

    func includes(text: String) -> Bool {
        body.localizedCaseInsensitiveContains(text)
    }

    func printDetails() {
        printSummaryLine()
        log(body.trimmingCharacters(in: .whitespacesAndNewlines), unformatted: true)

        let react = reactions
        if react.hasItems {
            let reactionList: [String] = react.compactMap {
                if let u = $0.user {
                    return "[\($0.emoji) @\(u.login)]"
                }
                return nil
            }
            log(reactionList.joined(separator: " "))
        }
        log()
    }

    func printSummaryLine() {
        if let a = author?.login {
            log("[![*@\(a)*] \(agoFormat(prefix: "Commented ", since: createdAt))!]")
        }
    }

    var mentionsMe: Bool {
        body.localizedCaseInsensitiveContains(config.myLogin)
    }

    var reactions: [Reaction] {
        children(field: "reactions")
    }

    var issue: Issue? {
        if let parentId = parents["Issue:comments"]?.first?.parentId {
            return Issue.allItems[parentId]
        }
        return nil
    }

    var pullRequest: PullRequest? {
        if let parentId = parents["PullRequest:comments"]?.first?.parentId {
            return PullRequest.allItems[parentId]
        }
        return nil
    }

    var review: Review? {
        if let parentId = parents["Review:comments"]?.first?.parentId {
            return Review.allItems[parentId]
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
        for c in reactions {
            var C = c
            C.setSyncStatus(status, andChildren: true)
            Reaction.allItems[c.id] = C
        }
    }

    @TrailerQL.ElementsBuilder
    private static func commentFields() -> [any Element] {
        Field.id
        Field("body")
        Field("viewerDidAuthor")
        Field("createdAt")
        Field("updatedAt")
        Group("reactions") { Field("totalCount") }
        Group("author") { User.fragment }
    }

    static let fragmentForItems = Fragment(on: "IssueComment", elements: commentFields)
    static let fragmentForReviews = Fragment(on: "PullRequestReviewComment", elements: commentFields)

    static let pullRequestReviewCommentReactionFragment = Fragment(on: "PullRequestReviewComment") {
        Field.id // not using fragment, no need to re-parse
        Group("reactions", paging: .first(count: 100, paging: true)) { Reaction.fragment }
    }

    static let issueCommentReactionFragment = Fragment(on: "IssueComment") {
        Field.id // not using fragment, no need to re-parse
        Group("reactions", paging: .first(count: 100, paging: true)) { Reaction.fragment }
    }
}
