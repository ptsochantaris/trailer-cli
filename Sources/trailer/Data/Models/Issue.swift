import Foundation
import Lista
import TrailerJson
import TrailerQL

@MainActor
struct Issue: Item, Announceable, Closeable, Sortable {
    var id: String
    var parents: [String: Lista<Relationship>]
    var syncState = SyncState.none
    var elementType: String

    static var allItems = [String: Issue]()
    static let typeName = "Issue"

    var bodyText = ""
    var createdAt = Date.distantPast
    var updatedAt = Date.distantPast
    var number = 0
    var title = ""
    var url = emptyURL
    var state = ItemState.closed
    var viewerDidAuthor = false
    var syncNeedsReactions = false

    private enum CodingKeys: CodingKey {
        case id
        case parents
        case elementType
        case bodyText
        case createdAt
        case updatedAt
        case number
        case title
        case url
        case state
        case viewerDidAuthor
    }

    mutating func apply(_ node: TypedJson.Entry) -> Bool {
        guard ((try? node.keys)?.count ?? 0) > 8 else { return false }

        syncNeedsReactions = node.potentialObject(named: "reactions")?.potentialInt(named: "totalCount") ?? 0 > 0

        bodyText = node.potentialString(named: "bodyText") ?? ""
        createdAt = GHDateFormatter.parseGH8601(node.potentialString(named: "createdAt")) ?? .distantPast
        updatedAt = GHDateFormatter.parseGH8601(node.potentialString(named: "updatedAt")) ?? .distantPast
        number = node.potentialInt(named: "number") ?? 0
        title = node.potentialString(named: "title") ?? ""
        url = URL(string: node.potentialString(named: "url") ?? "") ?? emptyURL
        state = ItemState(rawValue: node.potentialString(named: "state") ?? "CLOSED") ?? ItemState.closed
        viewerDidAuthor = node.potentialBool(named: "viewerDidAuthor") ?? false
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

    var type: Int {
        1
    }

    var headRefName: String {
        ""
    }

    var shouldAnnounceClosure: Bool {
        state == .closed
    }

    func announceClosure() {
        printSummaryLine(closing: true)
    }

    var commentedByMe: Bool {
        comments.contains(where: \.viewerDidAuthor)
    }

    var mentionsMe: Bool {
        if bodyText.localizedCaseInsensitiveContains(config.myLogin) {
            return true
        }
        return comments.contains { $0.mentionsMe }
    }

    var isAssignedToMe: Bool {
        if let u = config.myUser {
            return assignees.contains(u)
        }
        return false
    }

    var hasNewComments: Bool {
        comments.contains(where: { $0.syncState == .new && !$0.viewerDidAuthor })
    }

    func commentsInclude(text: String) -> Bool {
        comments.contains { $0.includes(text: text) }
    }

    func printSummaryLine() {
        printSummaryLine(closing: false)
    }

    func printSummaryLine(closing: Bool) {
        var line = "[!"
        if closing, state == .closed {
            line += "[B*CLOSED"
        } else if syncState == .new {
            line += "[R*NEW"
        } else if hasNewComments {
            line += "[C*COMMENTED"
        } else {
            line += "[*>"
        }
        line += "*]"

        let components = Lista<String>(value: line)

        if listFieldsDefinition.type {
            components.push("Issue")
        }
        if listFieldsDefinition.number {
            components.push("[*\(number)*]")
        }
        if listFieldsDefinition.title {
            components.push(title)
        }

        let x = components.pop()! + "!]"
        components.push(x)

        if listFieldsDefinition.labels, !labels.isEmpty {
            let l = labels.map(\.id).joined(separator: "] [")
            components.push("[\(l)]")
        }
        if listFieldsDefinition.repo, let r = repo {
            components.push("(\(r.nameWithOwner))")
        }
        if listFieldsDefinition.author, let a = author {
            components.push("(@\(a.login))")
        }
        if listFieldsDefinition.created {
            let a = agoFormat(prefix: "", since: createdAt)
            components.push("(Created \(a))")
        }
        if listFieldsDefinition.updated {
            let a = agoFormat(prefix: "", since: updatedAt)
            components.push("(Updated \(a))")
        }
        if listFieldsDefinition.url {
            components.push("[C*\(url.absoluteString)*]")
        }

        log(components.reversed().joined(separator: " "))
    }

    func announceIfNeeded(notificationMode: NotificationMode) {
        if let r = repo, r.syncState == .updated {
            if syncState == .new {
                switch notificationMode {
                case .consoleCommentsAndReviews, .standard:
                    printSummaryLine()
                case .none:
                    break
                }
            } else if syncState == .updated, hasNewComments {
                printSummaryLine()
            }
        }
    }

    func printDetails() {
        log()
        let ra = TTY.rightAlign("#\(number)")
        log("[![*\(ra)*] \(title)!]")
        let l = labels
        if l.count > 0 {
            log("\t\t[" + l.map(\.id).joined(separator: "] [") + "]")
        }
        log()
        if let r = repo {
            log("           [$Repo!] \(r.nameWithOwner)")
        }
        log("            [$URL!] \(url.absoluteString)")
        log(agoFormat(prefix: "        [$Created!] ", since: createdAt) + " by @" + (author?.login ?? ""))
        log(agoFormat(prefix: "        [$Updated!] ", since: updatedAt))
        if let m = milestone {
            log("      [$Milestone!] \(m.title)")
        }

        let commentCount = comments.count
        if commentCount > 0 {
            log("       [$Comments!] \(commentCount)")
        }
        log()

        let react = reactions
        if react.hasItems {
            log("[!Reactions!]")
            let line = react.map { "[\($0.emoji) @\($0.user?.login ?? "")]" }.joined(separator: " ")
            log(line)
            log()
        }

        if CommandLine.argument(exists: "-body") {
            let b = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
            if b.count > 0 {
                log("[!Body!]")
                log(b, unformatted: true)
                log()
            }
        }

        if CommandLine.argument(exists: "-comments") {
            let co = comments.sorted(by: { $0.createdAt < $1.createdAt })
            if co.hasItems {
                for c in co {
                    c.printDetails()
                }
                log()
            }
        }
    }

    var comments: [Comment] {
        children(field: "comments")
    }

    var reactions: [Reaction] {
        children(field: "reactions")
    }

    var labels: [Label] {
        children(field: "labels")
    }

    var assignees: [User] {
        children(field: "assignees")
    }

    var milestone: Milestone? {
        let c: [Milestone] = children(field: "milestone")
        return c.first
    }

    var author: User? {
        let c: [User] = children(field: "author")
        return c.first
    }

    mutating func setChildrenSyncStatus(_ status: SyncState) {
        for c in comments {
            var C = c
            C.setSyncStatus(status, andChildren: true)
            Comment.allItems[c.id] = C
        }
        for c in reactions {
            var C = c
            C.setSyncStatus(status, andChildren: true)
            Reaction.allItems[c.id] = C
        }
        for c in labels {
            var C = c
            C.setSyncStatus(status, andChildren: true)
            Label.allItems[c.id] = C
        }
        for c in assignees {
            var C = c
            C.setSyncStatus(status, andChildren: true)
            User.allItems[c.id] = C
        }
        if var c = milestone {
            c.setSyncStatus(status, andChildren: true)
            Milestone.allItems[c.id] = c
        }
        if var c = author {
            c.setSyncStatus(status, andChildren: true)
            User.allItems[c.id] = c
        }
    }

    var repo: Repo? {
        if let repoId = parents["Repo:issues"]?.first?.parentId {
            return Repo.allItems[repoId]
        }
        return nil
    }

    static let fragment = Fragment(on: "Issue") {
        Field.id
        Field("bodyText")
        Field("createdAt")
        Field("updatedAt")
        Field("number")
        Field("title")
        Field("url")
        Field("state")
        Field("viewerDidAuthor")

        Group("milestone") { Milestone.fragment }
        Group("author") { User.fragment }
        Group("labels", paging: .first(count: 20, paging: true)) { Label.fragment }
        Group("assignees", paging: .first(count: 20, paging: true)) { User.fragment }
        Group("reactions") { Field("totalCount") }
    }

    static let reactionsFragment = Fragment(on: "Issue") {
        Field.id // not using fragment, no need to re-parse
        Group("reactions", paging: .first(count: 100, paging: true)) { Reaction.fragment }
    }

    static let commentsFragment = Fragment(on: "Issue") {
        Field.id // not using fragment, no need to re-parse
        Group("comments", paging: .first(count: 100, paging: true)) { Comment.fragmentForItems }
    }

    static var fragmentWithComments: Fragment {
        fragment.addingElement(
            Group("comments", paging: .first(count: 100, paging: true)) { Comment.fragmentForItems }
        )
    }
}
