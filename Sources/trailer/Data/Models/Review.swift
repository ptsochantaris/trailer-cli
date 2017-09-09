//
//  Review.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

enum ReviewState: String, Codable {
	case pending, commented, approved, changes_requested, dimissed
	init?(rawValue: String) {
		switch rawValue.lowercased() {
		case "pending": self = ReviewState.pending
		case "commented": self = ReviewState.commented
		case "approved": self = ReviewState.approved
		case "changes_requested": self = ReviewState.changes_requested
		case "dimissed": self = ReviewState.dimissed
		default: return nil
		}
	}
}

struct Review: Item, Announceable {
	var id: String
	var parents: [String: [Relationship]]
	var syncState: SyncState
	var elementType: String

	static var allItems = [String:Review]()
	static var idField = "id"

	var state = ReviewState.pending
	var body = ""
	var viewerDidAuthor = false
	var createdAt = Date.distantPast
	var updatedAt = Date.distantPast

    var syncNeedsComments = false

	var comments: [Comment] {
		return children(field: "comments")
	}

	private enum CodingKeys : CodingKey {
		case id
		case parents
		case elementType
		case state
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
		state = ReviewState(rawValue: try c.decode(String.self, forKey: .state)) ?? ReviewState.pending
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
		try c.encode(state, forKey: .state)
		try c.encode(body, forKey: .body)
		try c.encode(viewerDidAuthor, forKey: .viewerDidAuthor)
		try c.encode(createdAt, forKey: .createdAt)
		try c.encode(updatedAt, forKey: .updatedAt)
	}

	mutating func apply(_ node: [AnyHashable:Any]) -> Bool {
		guard node.keys.count > 5 else { return false }

        syncNeedsComments = (node["comments"] as? [AnyHashable : Any])?["totalCount"] as? Int ?? 0 > 0

		state = ReviewState(rawValue: node["state"] as? String ?? "PENDING") ?? ReviewState.pending
		body = node["body"] as? String ?? ""
		createdAt = GHDateFormatter.parseGH8601(node["createdAt"] as? String) ?? Date.distantPast
		updatedAt = GHDateFormatter.parseGH8601(node["updatedAt"] as? String) ?? Date.distantPast
		viewerDidAuthor = node["viewerDidAuthor"] as? Bool ?? false
		return true
	}

	init?(id: String, type: String, parents: [String: [Relationship]], node: [AnyHashable:Any]) {
		self.id = id
		self.parents = parents
		self.elementType = type
		syncState = .new
		if !apply(node) {
			return nil
		}
	}

    func announceIfNeeded(notificationMode: NotificationMode) {
		if notificationMode != .consoleCommentsAndReviews || syncState != .new { return }

		if let p = pullRequest, p.syncState != .new, let re = pullRequest?.repo, let a = p.author?.login, re.syncState != .new {
			let r = re.nameWithOwner
			let d: String
			switch state {
			case .approved:
				d = "[\(r)] @\(a) reviewed [G*(approving)*]"
			case .changes_requested:
				d = "[\(r)] @\(a) reviewed [R*(requesting changes)*]"
			case .commented where !body.isEmpty:
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
		if !body.isEmpty {
            log(body.trimmingCharacters(in: .whitespacesAndNewlines), unformatted: true)
			log()
		}
	}

    func printSummaryLine() {
		printHeader()
		log()
    }

	var pullRequest: PullRequest? {
		if let parentId = parents["PullRequest:reviews"]?.first?.parentId {
			return PullRequest.allItems[parentId]
		}
		return nil
	}

	var author: User? {
		return children(field: "author").first
	}

	var mentionsMe: Bool {
		if body.localizedCaseInsensitiveContains(config.myLogin) {
			return true
		}
		return comments.contains { $0.mentionsMe }
	}

	static let fragment = Fragment(name: "reviewFields", on: "PullRequestReview", fields: [
		Field(name: "id"),
		Field(name: "body"),
		Field(name: "state"),
		Field(name: "viewerDidAuthor"),
		Field(name: "createdAt"),
		Field(name: "updatedAt"),
		Group(name: "author", fields: [User.fragment]),
        Group(name: "comments", fields: [Field(name: "totalCount")]),
		])

    static let commentsFragment = Fragment(name: "ReviewCommentsFragment", on: "PullRequestReview", fields: [
        Field(name: "id"), // not using fragment, no need to re-parse
        Group(name: "comments", fields: [Comment.fragmentForReviews], usePaging: true)
        ])
}
