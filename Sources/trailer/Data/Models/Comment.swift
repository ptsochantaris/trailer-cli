//
//  Comment.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

struct Comment: Item, Announceable {
	var id: String
	var parents: [String: [Relationship]]
	var syncState: SyncState
	var elementType: String

	static var allItems = [String:Comment]()
	static var idField = "id"

	var syncNeedsReactions = false

	var body = ""
	var viewerDidAuthor = false
	var createdAt = Date.distantPast
	var updatedAt = Date.distantPast

	private enum CodingKeys : CodingKey {
		case id
		case parents
		case elementType
		case body
		case viewerDidAuthor
		case createdAt
		case updatedAt
	}

	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		id = try c.decode(String.self, forKey: .id)
		parents = try c.decode([String: [Relationship]].self, forKey: .parents)
		elementType = try c.decode(String.self, forKey: .elementType)
		body = try c.decode(String.self, forKey: .body)
		viewerDidAuthor = try c.decode(Bool.self, forKey: .viewerDidAuthor)
		createdAt = try c.decode(Date.self, forKey: .createdAt)
		updatedAt = try c.decode(Date.self, forKey: .updatedAt)
		syncState = .none
	}

	func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: CodingKeys.self)
		try c.encode(id, forKey: .id)
		try c.encode(parents, forKey: .parents)
		try c.encode(elementType, forKey: .elementType)
		try c.encode(body, forKey: .body)
		try c.encode(viewerDidAuthor, forKey: .viewerDidAuthor)
		try c.encode(createdAt, forKey: .createdAt)
		try c.encode(updatedAt, forKey: .updatedAt)
	}

	mutating func apply(_ node: [AnyHashable:Any]) -> Bool {
		guard node.keys.count > 5 else { return false }

		syncNeedsReactions = (node["reactions"] as? [AnyHashable : Any])?["totalCount"] as? Int ?? 0 > 0
		body = node["body"] as? String ?? ""
		viewerDidAuthor = node["viewerDidAuthor"] as? Bool ?? false
		createdAt = GHDateFormatter.parseGH8601(node["createdAt"] as? String) ?? Date.distantPast
		updatedAt = GHDateFormatter.parseGH8601(node["updatedAt"] as? String) ?? Date.distantPast
		return true
	}

	init?(id: String, type: String, node: [AnyHashable:Any]) {
		self.id = id
		self.syncState = .new
		self.parents = [String:[Relationship]]()
		self.elementType = type
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

            case .standard, .none:
                return
            }
        }
    }

	func includes(text: String) -> Bool {
		return body.localizedCaseInsensitiveContains(text)
	}

	func printDetails() {
        printSummaryLine()
        log(body.trimmingCharacters(in: .whitespacesAndNewlines), unformatted: true)

		let react = reactions
		if !react.isEmpty {
			let reactionList = react.flatMap {
				if let u = $0.user {
					return "[\($0.emoji)  @\(u.login)]"
				}
				return nil
			}
			log(reactionList.joined(separator: ", "))
		}
        log()
	}

    func printSummaryLine() {
        if let a = author?.login {
            log("[![*@\(a)*] \(agoFormat(prefix: "Commented ", since: createdAt))!]")
        }
    }

	var mentionsMe: Bool {
		return body.localizedCaseInsensitiveContains(config.myLogin)
	}

	var reactions: [Reaction] {
		return children(field: "reactions")
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
		return children(field: "author").first
	}

	mutating func assumeChildrenSynced() {
		if var u = author {
			u.assumeSynced(andChildren: true)
			User.allItems[u.id] = u
		}
	}
	
	static let commentFields: [Element] = [
		Field(name: "id"),
		Field(name: "body"),
		Field(name: "viewerDidAuthor"),
		Field(name: "createdAt"),
		Field(name: "updatedAt"),
		Group(name: "reactions", fields: [Field(name: "totalCount")]),
		Group(name: "author", fields: [User.fragment])
	]

	static let fragmentForItems = Fragment(name: "commentFieldsForItems", on: "IssueComment", elements: commentFields)
    static let fragmentForReviews = Fragment(name: "commentFieldsForReviews", on: "PullRequestReviewComment", elements: commentFields)

    static let pullRequestReviewCommentReactionFragment = Fragment(name: "PullRequestReviewCommentReactionFragment", on: "PullRequestReviewComment", elements: [
        Field(name: "id"), // not using fragment, no need to re-parse
        Group(name: "reactions", fields: [Reaction.fragment], usePaging: true)
        ])

    static let issueCommentReactionFragment = Fragment(name: "IssueCommentReactionsFragment", on: "IssueComment", elements: [
        Field(name: "id"), // not using fragment, no need to re-parse
        Group(name: "reactions", fields: [Reaction.fragment], usePaging: true)
        ])

}

