import Foundation
import Lista
import TrailerJson
import TrailerQL

enum MergeableState: String, Codable {
    case mergeable, conflicting, unknown
    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "mergeable": self = MergeableState.mergeable
        case "conflicting": self = MergeableState.conflicting
        case "unknown": self = MergeableState.unknown
        default: return nil
        }
    }
}

@MainActor
protocol Sortable {
    var title: String { get }
    var createdAt: Date { get }
    var updatedAt: Date { get }
    var headRefName: String { get }
    var number: Int { get }
    var repo: Repo? { get }
    var author: User? { get }
    var type: Int { get }
}

@MainActor
struct PullRequest: Item, Announceable, Closeable, Sortable {
    var id: String
    var parents: [String: Lista<Relationship>]
    var syncState: SyncState
    var elementType: String

    static var allItems = [String: PullRequest]()
    static let typeName = "PullRequest"

    var mergeable = MergeableState.unknown
    var bodyText = ""
    var state = ItemState.closed
    var createdAt = Date.distantPast
    var updatedAt = Date.distantPast
    var mergedAt = Date.distantPast
    var number = 0
    var title = ""
    var headRefName = ""
    var url = Config.emptyURL
    var viewerDidAuthor = false

    var syncNeedsReactions = false

    private enum CodingKeys: CodingKey {
        case id
        case parents
        case elementType
        case mergeable
        case bodyText
        case state
        case createdAt
        case updatedAt
        case number
        case title
        case url
        case viewerDidAuthor
        case mergedAt
        case headRefName
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        parents = try c.decode([String: Lista<Relationship>].self, forKey: .parents)
        elementType = try c.decode(String.self, forKey: .elementType)
        mergeable = try c.decode(MergeableState.self, forKey: .mergeable)
        bodyText = try c.decode(String.self, forKey: .bodyText)
        state = try c.decode(ItemState.self, forKey: .state)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        mergedAt = try c.decodeIfPresent(Date.self, forKey: .mergedAt) ?? Date.distantPast
        number = try c.decode(Int.self, forKey: .number)
        title = try c.decode(String.self, forKey: .title)
        url = try c.decode(URL.self, forKey: .url)
        viewerDidAuthor = try c.decode(Bool.self, forKey: .viewerDidAuthor)
        headRefName = try c.decodeIfPresent(String.self, forKey: .headRefName) ?? ""
        syncState = .none
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(parents, forKey: .parents)
        try c.encode(elementType, forKey: .elementType)
        try c.encode(mergeable, forKey: .mergeable)
        try c.encode(bodyText, forKey: .bodyText)
        try c.encode(state, forKey: .state)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(mergedAt, forKey: .mergedAt)
        try c.encode(number, forKey: .number)
        try c.encode(title, forKey: .title)
        try c.encode(url, forKey: .url)
        try c.encode(viewerDidAuthor, forKey: .viewerDidAuthor)
        try c.encode(headRefName, forKey: .headRefName)
    }

    mutating func apply(_ node: TypedJson.Entry) -> Bool {
        guard ((try? node.keys)?.count ?? 0) > 9 else { return false }

        syncNeedsReactions = node.potentialObject(named: "reactions")?.potentialInt(named: "totalCount") ?? 0 > 0

        mergeable = MergeableState(rawValue: node.potentialString(named: "mergeable") ?? "UNKNOWN") ?? MergeableState.unknown
        bodyText = node.potentialString(named: "bodyText") ?? ""
        headRefName = node.potentialString(named: "headRefName") ?? ""
        state = ItemState(rawValue: node.potentialString(named: "state") ?? "CLOSED") ?? ItemState.closed
        createdAt = GHDateFormatter.parseGH8601(node.potentialString(named: "createdAt")) ?? .distantPast
        updatedAt = GHDateFormatter.parseGH8601(node.potentialString(named: "updatedAt")) ?? .distantPast
        mergedAt = GHDateFormatter.parseGH8601(node.potentialString(named: "mergedAt")) ?? .distantPast
        number = node.potentialInt(named: "number") ?? 0
        title = node.potentialString(named: "title") ?? ""
        url = URL(string: node.potentialString(named: "url") ?? "") ?? Config.emptyURL
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
        0
    }

    var shouldAnnounceClosure: Bool {
        state == .closed || state == .merged
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
        return comments.contains { $0.mentionsMe } || reviews.contains { $0.mentionsMe }
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

    var hasNewReviews: Bool {
        reviews.contains(where: { $0.syncState == .new && !$0.viewerDidAuthor })
    }

    func commentsOrReviewsInclude(text: String) -> Bool {
        if comments.contains(where: { $0.includes(text: text) }) {
            return true
        }
        if reviews.contains(where: { $0.includes(text: text) }) {
            return true
        }
        return false
    }

    var isRed: Bool {
        latestStatuses.contains(where: { $0.state == .error || $0.state == .failure })
    }

    var isGreen: Bool {
        !latestStatuses.contains(where: { $0.state != .success })
    }

    func printSummaryLine() {
        printSummaryLine(closing: false)
    }

    func printSummaryLine(closing: Bool) {
        var line = "[!"
        if closing, state == .closed {
            line += "[B*CLOSED"
        } else if closing, state == .merged {
            line += "[G*MERGED"
        } else if syncState == .new {
            line += "[R*NEW"
        } else if hasNewComments {
            line += "[C*COMMENTED"
        } else if hasNewReviews {
            line += "[C*REVIEWED"
        } else {
            if isRed {
                line += "[R*"
            } else if isGreen {
                line += "[G*"
            } else {
                line += "[*"
            }
            if mergeable == .conflicting {
                line += "x"
            } else {
                line += ">"
            }
        }
        line += "*]"

        let components = Lista<String>(value: line)

        if listFieldsDefinition.type {
            components.push("PR")
        }
        if listFieldsDefinition.number {
            components.push("[*\(number)*]")
        }
        if listFieldsDefinition.title {
            components.push(title)
        }

        let x = components.pop()! + "!]"
        components.push(x)

        if listFieldsDefinition.labels, labels.hasItems {
            let l = labels.map(\.name).joined(separator: "] [")
            components.push("[\(l)]")
        }
        if listFieldsDefinition.repo, let r = repo {
            components.push("(\(r.nameWithOwner))")
        }
        if listFieldsDefinition.branch, headRefName.hasItems {
            components.push("(\(headRefName))")
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

    var parentIsNew: Bool {
        (repo?.syncState ?? .new) == .new
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

    private var latestReviews: [Review] {
        var author2latestReview = [String: Review]()
        let revs = reviews.sorted { $0.createdAt < $1.createdAt }
        for review in revs {
            if let a = review.author?.login {
                author2latestReview[a] = review
            }
        }
        return author2latestReview.values.sorted { $0.createdAt < $1.createdAt }
    }

    var pendingReview: Bool {
        let requests = reviewRequests
        if requests.isEmpty { return false }

        let latestReviewResults = latestReviews.filter { $0.state == .approved || $0.state == .changes_requested }.compactMap { $0.author?.login }
        let waitingFor = requests.compactMap { $0.reviewer?.login }.filter { !latestReviewResults.contains($0) }
        return waitingFor.count > 0
    }

    var allReviewersApprove: Bool {
        let r = latestReviews
        return r.count > 0 && !(r.contains { $0.state != .approved })
    }

    var someReviewersBlock: Bool {
        latestReviews.contains { $0.state == .changes_requested }
    }

    func printDetails() {
        log()
        let ra = TTY.rightAlign("#\(number)")
        log("[![*\(ra)*] \(title)!]")
        let l = labels
        if l.count > 0 {
            log("\t\t[" + l.map(\.name).joined(separator: "] [") + "]")
        }
        log()
        if let r = repo {
            log("           [$Repo!] \(r.nameWithOwner)")
        }
        if headRefName.hasItems {
            log("         [$Branch!] \(headRefName)")
        }
        log("            [$URL!] \(url.absoluteString)")
        log(agoFormat(prefix: "        [$Created!] ", since: createdAt) + " by @" + (author?.login ?? ""))
        log(agoFormat(prefix: "        [$Updated!] ", since: updatedAt))

        if mergedAt == Date.distantPast {
            var mergeLine = "    [$Merge check!] [!"
            switch mergeable {
            case .conflicting:
                mergeLine += "[R*"
            case .mergeable:
                mergeLine += "[G*"
            case .unknown:
                mergeLine += "[*"
            }
            mergeLine += mergeable.rawValue.capitalized
            mergeLine += "*]!]"
            log(mergeLine)
        } else {
            log("         [![G*Merged \(agoFormat(prefix: "", since: mergedAt))*]!]")
        }

        if let m = milestone {
            log("      [$Milestone!] \(m.title)")
        }

        let rs = reviews
        let reviewComments = rs.reduce([]) { $0 + $1.comments }
        let reviewsWithText = rs.filter { !($0.state == .commented && $0.body.isEmpty) }
        let commentItems = reviewsWithText as [DetailPrinter] + reviewComments as [DetailPrinter] + comments as [DetailPrinter]
        if commentItems.count > 0 {
            log("       [$Comments!] \(commentItems.count)")
        }

        log()

        let react = reactions
        if react.hasItems {
            log("[!Reactions!]")
            let line = react.map { "[\($0.emoji) @\($0.user?.login ?? "")]" }.joined(separator: " ")
            log(line)
            log()
        }

        let st = latestStatuses
        if st.hasItems {
            log("[!Statuses")
            for s in st {
                switch s.state {
                case .empty, .neutral, .skipped:
                    log("\(s.context) - \(s.description)")
                case .expected, .pending:
                    log("[*[ ] \(s.context) - \(s.description)*]")
                case .success:
                    log("[G*[+] \(s.context) - \(s.description)*]")
                default:
                    log("[R*[X] \(s.context) - \(s.description)*]")
                }
            }
            log("!]")
        }

        let latest = latestReviews
        if latest.hasItems {
            let approvingReviewers = latest.filter { $0.state == .approved }.compactMap { $0.author?.login }.map { "@" + $0 }
            let blockingReviewers = latest.filter { $0.state == .changes_requested }.compactMap { $0.author?.login }.map { "@" + $0 }
            let pendingReviewers = reviewRequests.compactMap { $0.reviewer?.login }.map { "@" + $0 }.filter { !(approvingReviewers.contains($0) || blockingReviewers.contains($0)) }
            if approvingReviewers.hasItems || blockingReviewers.hasItems || pendingReviewers.hasItems {
                log("[!Reviews")
                if approvingReviewers.count > 0 {
                    log("[G*[+] " + approvingReviewers.joined(separator: ", ") + " approved changes")
                }
                if blockingReviewers.count > 0 {
                    if blockingReviewers.count > 1 {
                        log("[R*[X] " + blockingReviewers.joined(separator: ", ") + " request changes")
                    } else {
                        log("[R*[X] " + blockingReviewers.joined(separator: ", ") + " requests changes")
                    }
                }
                if pendingReviewers.count > 0 {
                    if pendingReviewers.count > 1 {
                        log("[*[ ] " + pendingReviewers.joined(separator: ", ") + " haven't reviewed yet")
                    } else {
                        log("[*[ ] " + pendingReviewers.joined(separator: ", ") + " hasn't reviewed yet")
                    }
                }
                log("*]!]")
            }
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
            let co = commentItems.sorted(by: { $0.createdAt < $1.createdAt })
            if co.hasItems {
                for c in co {
                    c.printDetails()
                }
                log()
            }
        }
    }

    var latestStatuses: [Status] {
        var res = [String: Status]()
        for s in statuses {
            res[s.id] = s
        }
        return res.values.sorted { $0.createdAt < $1.createdAt }
    }

    var reactions: [Reaction] {
        children(field: "reactions")
    }

    var comments: [Comment] {
        children(field: "comments")
    }

    var labels: [Label] {
        children(field: "labels")
    }

    var statuses: [Status] {
        children(field: "contexts") + children(field: "checkRuns")
    }

    var reviews: [Review] {
        children(field: "reviews")
    }

    var assignees: [User] {
        children(field: "assignees")
    }

    var reviewRequests: [ReviewRequest] {
        children(field: "reviewRequests")
    }

    var repo: Repo? {
        if let repoId = parents["Repo:pullRequests"]?.first?.parentId {
            return Repo.allItems[repoId]
        }
        return nil
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
        for c in reviews {
            var C = c
            C.setSyncStatus(status, andChildren: true)
            Review.allItems[c.id] = C
        }
        for c in reviewRequests {
            var C = c
            C.setSyncStatus(status, andChildren: true)
            ReviewRequest.allItems[c.id] = C
        }
        for c in statuses {
            var C = c
            C.setSyncStatus(status, andChildren: true)
            Status.allItems[c.id] = C
        }
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

    static let fragment = Fragment(on: "PullRequest") {
        Field.id
        Field("updatedAt")
        Field("mergeable")
        Field("mergedAt")
        Field("bodyText")
        Field("state")
        Field("createdAt")
        Field("updatedAt")
        Field("number")
        Field("title")
        Field("url")
        Field("headRefName")
        Field("viewerDidAuthor")

        Group("milestone") { Milestone.fragment }
        Group("author") { User.fragment }

        Group("labels", paging: .first(count: 20, paging: true)) { Label.fragment }
        Group("assignees", paging: .first(count: 20, paging: true)) { User.fragment }
        Group("reviews", paging: .first(count: 100, paging: true)) { Review.fragment }
        Group("reviewRequests", paging: .first(count: 20, paging: true)) { ReviewRequest.fragment }

        Group("reactions") { Field("totalCount") }

        Group("commits", paging: .last(count: 1)) {
            Group("commit") {
                Group("status") {
                    Group("contexts") {
                        Status.fragmentForStatus
                    }
                }
                Group("checkSuites", paging: .first(count: 20, paging: true)) {
                    Group("checkRuns", paging: .first(count: 20, paging: true)) {
                        Status.fragmentForCheck
                    }
                }
            }
        }
    }

    static var fragmentWithComments: Fragment {
        fragment.addingElement(
            Group("comments", paging: .first(count: 100, paging: true)) { Comment.fragmentForItems }
        )
    }

    static let reactionsFragment = Fragment(on: "PullRequest") {
        Field.id // not using fragment, no need to re-parse
        Group("reactions", paging: .first(count: 100, paging: true)) { Reaction.fragment }
    }

    static let commentsFragment = Fragment(on: "PullRequest") {
        Field.id // not using fragment, no need to re-parse
        Group("comments", paging: .first(count: 100, paging: true)) { Comment.fragmentForItems }
    }
}
