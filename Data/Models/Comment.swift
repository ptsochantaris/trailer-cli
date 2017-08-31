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

	var totalReactions: Int = 0

	var body = ""
	var viewerDidAuthor = false
	var createdAt = Date.distantPast
	var updatedAt = Date.distantPast

	private enum CodingKeys : CodingKey {
		case id
		case parents
		case elementType
		case totalReactions
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
		totalReactions = try c.decode(Int.self, forKey: .totalReactions)
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
		try c.encode(totalReactions, forKey: .totalReactions)
		try c.encode(body, forKey: .body)
		try c.encode(viewerDidAuthor, forKey: .viewerDidAuthor)
		try c.encode(createdAt, forKey: .createdAt)
		try c.encode(updatedAt, forKey: .updatedAt)
	}

	mutating func apply(_ node: [AnyHashable:Any]) -> Bool {
		guard node.keys.count > 5 else { return false }

		totalReactions = (node["reactions"] as? [AnyHashable : Any])?["totalCount"] as? Int ?? 0
		body = node["body"] as? String ?? ""
		viewerDidAuthor = node["viewerDidAuthor"] as? Bool ?? false
		createdAt = GHDateFormatter.parseGH8601(node["createdAt"] as? String) ?? Date.distantPast
		updatedAt = GHDateFormatter.parseGH8601(node["updatedAt"] as? String) ?? Date.distantPast
		return true
	}

	init?(id: String, type: String, parents: [String: [Relationship]], node: [AnyHashable:Any]) {
		self.id = id
		self.syncState = .new
		self.parents = parents
		self.elementType = type
		if !apply(node) {
			return nil
		}
	}

    func announceIfNeeded(notificationMode: NotificationMode) {
        if syncState == .new {
            switch notificationMode {
            case .consoleCommentsAndReviews:
                let a = author?.login ?? ""
                let n: Int
                let t: String
                let r: String
                let inReview: Bool
                let inPr: Bool
                if let p = pullRequest {
                    n = p.number; t = p.title; r = p.repo?.nameWithOwner ?? ""
                    inReview = false
                    inPr = true
                } else if let i = issue {
                    n = i.number; t = i.title; r = i.repo?.nameWithOwner ?? ""
                    inReview = false
                    inPr = false
                } else if let rv = review, let p = rv.pullRequest {
                    n = p.number; t = p.title; r = p.repo?.nameWithOwner ?? ""
                    inReview = true
                    inPr = false
                } else {
                    break
                }
                let title = "[\(r)] @\(a) commented" + (inReview ? " [*(in review)*]" : "")
                let subtitle = (inPr ? "PR" : "Issue") + " #\(n) \(t)"
                Notifications.notify(title: title, subtitle: subtitle, details: body)

            case .standard, .none:
                break
            }
        }
    }

	func printDetails() {
        printSummaryLine()
        log(body.trimmingCharacters(in: .whitespacesAndNewlines), unformatted: true)
        log()
	}

    func printSummaryLine() {
        if let a = author?.login {
            log("[![*@\(a)*] \(agoFormat(prefix: "Commented ", since: createdAt))!]")
        }
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

	static let commentFields: [Element] = [
		Field(name: "id"),
		Field(name: "body"),
		Field(name: "viewerDidAuthor"),
		Field(name: "createdAt"),
		Field(name: "updatedAt"),
		Group(name: "reactions", fields: [Field(name: "totalCount")]),
		Group(name: "author", fields: [User.fragment])
	]

	static let fragment = Fragment(name: "commentFields", on: "IssueComment", fields: commentFields)
	static let reviewCommentFragment = Fragment(name: "commentFields", on: "PullRequestReviewComment", fields: commentFields)

	static let reactionsHolderIssueFragment = Fragment(name: "IssueReactionsHolder", on: "IssueComment", fields: [
		Field(name: "id"), // not using fragment, no need to re-parse
		Group(name: "reactions", fields: [Reaction.fragment], usePaging: true)
		])

	static let reactionsHolderPRFragment = Fragment(name: "PRReactionsHolder", on: "PullRequestReviewComment", fields: [
		Field(name: "id"), // not using fragment, no need to re-parse
		Group(name: "reactions", fields: [Reaction.fragment], usePaging: true)
		])

	static let reviewCommentHolderFragment = Fragment(name: "reviewHolder", on: "PullRequestReview", fields: [
		Field(name: "id"), // not using fragment, no need to re-parse
		Group(name: "comments", fields: [Comment.reviewCommentFragment], usePaging: true)
		])
}

