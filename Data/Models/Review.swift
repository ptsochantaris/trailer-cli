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

struct Review: Item, DetailPrinter {
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

	func printDetails() {
        printSummaryLine()
		if !body.isEmpty {
            log(body.trimmingCharacters(in: .whitespacesAndNewlines), unformatted: true)
			log()
		}
	}

    func printSummaryLine() {
        if let a = author?.login {
            log("[![*@\(a)*] \(agoFormat(prefix: "Reviewed ", since: createdAt))!]")
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
		return children(field: "author").first
	}

	static let fragment = Fragment(name: "reviewFields", on: "PullRequestReview", fields: [
		Field(name: "id"),
		Field(name: "body"),
		Field(name: "state"),
		Field(name: "viewerDidAuthor"),
		Field(name: "createdAt"),
		Field(name: "updatedAt"),
		Group(name: "author", fields: [User.fragment])
		])
}
