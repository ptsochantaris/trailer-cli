//
//  PullRequest.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

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

struct PullRequest: Item, Announceable, Closeable, Sortable {
	var id: String
	var parents: [String: [Relationship]]
	var syncState: SyncState
	var elementType: String

	static var allItems = [String:PullRequest]()
	static let idField = "id"

	var mergeable = MergeableState.unknown
	var bodyText = ""
	var state = ItemState.closed
	var createdAt = Date.distantPast
	var updatedAt = Date.distantPast
	var mergedAt = Date.distantPast
	var number: Int = 0
	var title = ""
	var headRefName = ""
	var url = emptyURL
	var viewerDidAuthor = false

    var syncNeedsReactions = false

	private enum CodingKeys : CodingKey {
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

	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		id = try c.decode(String.self, forKey: .id)
		parents = try c.decode([String: [Relationship]].self, forKey: .parents)
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

	func encode(to encoder: Encoder) throws {
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

	mutating func apply(_ node: [AnyHashable:Any]) -> Bool {
		guard node.keys.count > 9 else { return false }

        syncNeedsReactions = (node["reactions"] as? [AnyHashable : Any])?["totalCount"] as? Int ?? 0 > 0

        mergeable = MergeableState(rawValue: node["mergeable"] as? String ?? "UNKNOWN") ?? MergeableState.unknown
		bodyText = node["bodyText"] as? String ?? ""
		headRefName = node["headRefName"] as? String ?? ""
		state = ItemState(rawValue: node["state"] as? String ?? "CLOSED") ?? ItemState.closed
		createdAt = GHDateFormatter.parseGH8601(node["createdAt"] as? String) ?? Date.distantPast
		updatedAt = GHDateFormatter.parseGH8601(node["updatedAt"] as? String) ?? Date.distantPast
		mergedAt = GHDateFormatter.parseGH8601(node["mergedAt"] as? String) ?? Date.distantPast
		number = node["number"] as? Int ?? 0
		title = node["title"] as? String ?? ""
		url = URL(string: node["url"] as? String ?? "") ?? emptyURL
		viewerDidAuthor = node["viewerDidAuthor"] as? Bool ?? false
		return true
	}

	init?(id: String, type: String, node: [AnyHashable:Any]) {
		self.id = id
		self.parents = [String:[Relationship]]()
		self.elementType = type
		syncState = .new
		if !apply(node) {
			return nil
		}
	}

	var type: Int {
		return 0
	}

    var shouldAnnounceClosure: Bool {
        return state == .closed || state == .merged
    }

    func announceClosure() {
        printSummaryLine(closing: true)
    }

	var commentedByMe: Bool {
		return comments.contains(where: { $0.viewerDidAuthor })
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
        return comments.contains(where: { $0.syncState == .new && !$0.viewerDidAuthor })
    }

    var hasNewReviews: Bool {
        return reviews.contains(where: { $0.syncState == .new && !$0.viewerDidAuthor })
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
		return latestStatuses.contains(where: { $0.state == .error || $0.state == .failure })
	}

	var isGreen: Bool {
		return !latestStatuses.contains(where: { $0.state != .success })
	}

	func printSummaryLine() {
		printSummaryLine(closing : false)
	}
	func printSummaryLine(closing: Bool) {
		var components = [String]()
        var line = "[!"
        if closing && state == .closed {
            line += "[B*CLOSED"
        } else if closing && state == .merged {
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
		components.append(line)

		if listFieldsDefinition.type {
			components.append("PR")
		}
		if listFieldsDefinition.number {
			components.append("[*\(number)*]")
		}
		if listFieldsDefinition.title {
			components.append(title)
		}

		let x = components.popLast()! + "!]"
		components.append(x)

		if listFieldsDefinition.labels, labels.hasItems {
			let l = labels.map { $0.id }.joined(separator: "] [")
			components.append("[\(l)]")
		}
		if listFieldsDefinition.repo, let r = repo {
			components.append("(\(r.nameWithOwner))")
		}
		if listFieldsDefinition.branch, headRefName.hasItems {
			components.append("(\(headRefName))")
		}
		if listFieldsDefinition.author, let a = author {
			components.append("(@\(a.login))")
		}
		if listFieldsDefinition.created {
			let a = agoFormat(prefix: "", since: createdAt)
			components.append("(Created \(a))")
		}
		if listFieldsDefinition.updated {
			let a = agoFormat(prefix: "", since: updatedAt)
			components.append("(Updated \(a))")
		}
		if listFieldsDefinition.url {
			components.append("[C*\(url.absoluteString)*]")
		}

		log(components.joined(separator: " "))
	}

    var parentIsNew: Bool {
        return (repo?.syncState ?? .new) == .new
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
            } else if syncState == .updated && hasNewComments {
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
		if requests.count == 0 { return false }

		let latestReviewResults = latestReviews.filter { $0.state == .approved || $0.state == .changes_requested }.compactMap { $0.author?.login }
		let waitingFor = requests.compactMap { $0.reviewer?.login }.filter { !latestReviewResults.contains($0) }
		return waitingFor.count > 0
	}

	var allReviewersApprove: Bool {
		let r = latestReviews
		return r.count > 0 && !(r.contains { $0.state != .approved })
	}

	var someReviewersBlock: Bool {
		return latestReviews.contains { $0.state == .changes_requested }
	}

	func printDetails() {
		log()
        let ra = TTY.rightAlign("#\(number)")
		log("[![*\(ra)*] \(title)!]")
		let l = labels
		if l.count > 0 {
			log("\t\t[" + l.map({ $0.id }).joined(separator: "] [") + "]")
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
		let reviewComments = rs.reduce([], { $0 + $1.comments })
		let reviewsWithText = rs.filter { !($0.state == .commented && $0.body.isEmpty) }
		let commentItems = reviewsWithText as [DetailPrinter] + reviewComments as [DetailPrinter] + comments as [DetailPrinter]
		if commentItems.count > 0 {
			log("       [$Comments!] \(commentItems.count)")
		}

		log()

		let react = reactions
		if react.hasItems {
			log("[!Reactions!]")
			for r in react {
				if let u = r.user {
					log("\(r.emoji)  - @\(u.login)")
				}
			}
			log()
		}

		let st = latestStatuses
		if st.hasItems {
            log("[!Statuses")
			for s in st {
				let char: String
				switch s.state {
				case .error, .failure:
					char = "[R*[X]"
				case .expected, .pending:
					char = "[*[ ]"
				case .success:
					char = "[G*[+]"
				}
				log("\(char) \(s.context) - \(s.description)*]")
			}
            log("!]")
		}

		let latest = latestReviews
		if latest.hasItems {
			let approvingReviewers = latest.filter { $0.state == .approved }.compactMap { $0.author?.login }.map { "@"+$0 }
			let blockingReviewers = latest.filter { $0.state == .changes_requested }.compactMap { $0.author?.login }.map { "@"+$0 }
			let pendingReviewers = reviewRequests.compactMap { $0.reviewer?.login }.map { "@"+$0 }.filter { !(approvingReviewers.contains($0) || blockingReviewers.contains($0)) }
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
		var res = [String:Status]()
		for s in statuses {
			res[s.context] = s
		}
		return res.values.sorted { $0.createdAt < $1.createdAt }
	}
	
	var reactions: [Reaction] {
		return children(field: "reactions")
	}

	var comments: [Comment] {
		return children(field: "comments")
	}

	var labels: [Label] {
		return children(field: "labels")
	}

	var statuses: [Status] {
		return children(field: "contexts")
	}

	var reviews: [Review] {
		return children(field: "reviews")
	}

	var assignees: [User] {
		return children(field: "assignees")
	}

	var reviewRequests: [ReviewRequest] {
		return children(field: "reviewRequests")
	}

	var repo: Repo? {
		if let repoId = parents["Repo:pullRequests"]?.first?.parentId {
			return Repo.allItems[repoId]
		}
		return nil
	}

	var milestone: Milestone? {
		return children(field: "milestone").first
	}

	var author: User? {
		return children(field: "author").first
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

	static let fragment = Fragment(name: "prFields", on: "PullRequest", elements: [
		Field(name: "id"),
		Field(name: "updatedAt"),
		Field(name: "mergeable"),
		Field(name: "mergedAt"),
		Field(name: "bodyText"),
		Field(name: "state"),
		Field(name: "createdAt"),
		Field(name: "updatedAt"),
		Field(name: "number"),
		Field(name: "title"),
		Field(name: "url"),
		Field(name: "headRefName"),
		Field(name: "viewerDidAuthor"),

		Group(name: "milestone", fields: [Milestone.fragment]),
		Group(name: "author", fields: [User.fragment]),

		Group(name: "labels", fields: [Label.fragment], usePaging: true),
		Group(name: "assignees", fields: [User.fragment], usePaging: true),
		Group(name: "reviews", fields: [Review.fragment], usePaging: true),
		Group(name: "reviewRequests", fields: [ReviewRequest.fragment], usePaging: true),

        Group(name: "reactions", fields: [Field(name: "totalCount")]),

		Group(name: "commits", fields: [
			Group(name: "commit", fields: [
				Group(name: "status", fields: [
					Group(name: "contexts", fields: [
						Status.fragment
						])
					])
				])
			], usePaging: true, onlyLast: true)
		])

	static var fragmentWithComments: Fragment {
		var f = fragment
		f.addField(Group(name: "comments", fields: [Comment.fragmentForItems], usePaging: true))
		return f
	}

    static let reactionsFragment = Fragment(name: "PullRequestReactionFragment", on: "PullRequest", elements: [
        Field(name: "id"), // not using fragment, no need to re-parse
        Group(name: "reactions", fields: [Reaction.fragment], usePaging: true)
        ])

    static let commentsFragment = Fragment(name: "PullRequestCommentsFragment", on: "PullRequest", elements: [
        Field(name: "id"), // not using fragment, no need to re-parse
        Group(name: "comments", fields: [Comment.fragmentForItems], usePaging: true)
        ])
}
