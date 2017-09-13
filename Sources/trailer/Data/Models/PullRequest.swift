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

struct PullRequest: Item, Announceable, Closeable {
	var id: String
	var parents: [String: [Relationship]]
	var syncState: SyncState
	var elementType: String

	static var allItems = [String:PullRequest]()
	static var idField = "id"

	var mergeable = MergeableState.unknown
	var bodyText = ""
	var state = ItemState.closed
	var createdAt = Date.distantPast
	var updatedAt = Date.distantPast
	var number: Int = 0
	var title = ""
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
		number = try c.decode(Int.self, forKey: .number)
		title = try c.decode(String.self, forKey: .title)
		url = try c.decode(URL.self, forKey: .url)
		viewerDidAuthor = try c.decode(Bool.self, forKey: .viewerDidAuthor)
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
		try c.encode(number, forKey: .number)
		try c.encode(title, forKey: .title)
		try c.encode(url, forKey: .url)
		try c.encode(viewerDidAuthor, forKey: .viewerDidAuthor)
	}

	mutating func apply(_ node: [AnyHashable:Any]) -> Bool {
		guard node.keys.count > 9 else { return false }

        syncNeedsReactions = (node["reactions"] as? [AnyHashable : Any])?["totalCount"] as? Int ?? 0 > 0

        mergeable = MergeableState(rawValue: node["mergeable"] as? String ?? "UNKNOWN") ?? MergeableState.unknown
		bodyText = node["bodyText"] as? String ?? ""
		state = ItemState(rawValue: node["state"] as? String ?? "CLOSED") ?? ItemState.closed
		createdAt = GHDateFormatter.parseGH8601(node["createdAt"] as? String) ?? Date.distantPast
		updatedAt = GHDateFormatter.parseGH8601(node["updatedAt"] as? String) ?? Date.distantPast
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

	func printSummaryLine() {
		printSummaryLine(closing : false)
	}
	func printSummaryLine(closing: Bool) {
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
			line += "[*>"
		}
        line += "*] PR [*\(number)*] \(title)!]"
		if let r = repo {
			line += " (\(r.nameWithOwner))"
		}
		if let a = author {
			line += " (@\(a.login))"
		}
		log(line)
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
		log("            [$URL!] \(url.absoluteString)")
		log(agoFormat(prefix: "        [$Created!] ", since: createdAt) + " by @" + (author?.login ?? ""))
		log(agoFormat(prefix: "        [$Updated!] ", since: updatedAt))

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
		if !react.isEmpty {
			log("[!Reactions!]")
			for r in react {
				if let u = r.user {
					log("\(r.emoji)  - @\(u.login)")
				}
			}
			log()
		}

		let s = statuses
		if !s.isEmpty {
            log("[!Statuses")
			for s in statuses {
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

		let revs = reviews.sorted { $0.createdAt < $1.createdAt }
		let reviewRqs = reviewRequests
		if !revs.isEmpty || !reviewRqs.isEmpty {
			var reviewerToReview = [String: Review]()
			for review in revs {
				if (review.state == .changes_requested || review.state == .approved), let a = review.author {
					reviewerToReview[a.login] = review
				}
			}
			let approvingReviewers = reviewerToReview.values.filter({ $0.state == .approved }).flatMap({ $0.author?.login }).map({ "@"+$0 })
			let blockingReviewers = reviewerToReview.values.filter({ $0.state == .changes_requested }).flatMap({ $0.author?.login }).map({ "@"+$0 })
			let pendingReviewers = reviewRqs.flatMap({ $0.reviewer?.login }).map({ "@"+$0 }).filter({ !(approvingReviewers.contains($0) || blockingReviewers.contains($0)) })
			if !approvingReviewers.isEmpty || !blockingReviewers.isEmpty || !pendingReviewers.isEmpty {
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

		if commandLineArgument(matching: "-body") != nil {
			let b = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
			if b.count > 0 {
				log("[!Body!]")
                log(b, unformatted: true)
				log()
			}
		}

		if commandLineArgument(matching: "-comments") != nil {
			let co = commentItems.sorted(by: { $0.createdAt < $1.createdAt })
			if !co.isEmpty {
				for c in co {
					c.printDetails()
				}
				log()
			}
        }
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

	mutating func assumeChildrenSynced() {
		for c in reviews {
			var C = c
			C.assumeSynced(andChildren: true)
			Review.allItems[c.id] = C
		}
		for c in reviewRequests {
			var C = c
			C.assumeSynced(andChildren: true)
			ReviewRequest.allItems[c.id] = C
		}
		for c in statuses {
			var C = c
			C.assumeSynced(andChildren: true)
			Status.allItems[c.id] = C
		}
		for c in comments {
			var C = c
			C.assumeSynced(andChildren: true)
			Comment.allItems[c.id] = C
		}
		for c in reactions {
			var C = c
			C.assumeSynced(andChildren: true)
			Reaction.allItems[c.id] = C
		}
		for c in labels {
			var C = c
			C.assumeSynced(andChildren: true)
			Label.allItems[c.id] = C
		}
		for c in assignees {
			var C = c
			C.assumeSynced(andChildren: true)
			User.allItems[c.id] = C
		}
		if var c = milestone {
			c.assumeSynced(andChildren: true)
			Milestone.allItems[c.id] = c
		}
		if var c = author {
			c.assumeSynced(andChildren: true)
			User.allItems[c.id] = c
		}
	}

	static let fragment = Fragment(name: "prFields", on: "PullRequest", elements: [
		Field(name: "id"),
		Field(name: "updatedAt"),
		Field(name: "mergeable"),
		Field(name: "bodyText"),
		Field(name: "state"),
		Field(name: "createdAt"),
		Field(name: "updatedAt"),
		Field(name: "number"),
		Field(name: "title"),
		Field(name: "url"),
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
