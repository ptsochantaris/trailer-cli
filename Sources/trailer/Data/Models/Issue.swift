//
//  Issue.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

struct Issue: Item, Announceable, Closeable {
	var id: String
	var parents: [String: [Relationship]]
	var syncState: SyncState
	var elementType: String

	static var allItems = [String:Issue]()
	static var idField = "id"

	var bodyText = ""
	var createdAt = Date.distantPast
	var updatedAt = Date.distantPast
	var number: Int = 0
	var title = ""
	var url = emptyURL
	var state = ItemState.closed
	var viewerDidAuthor = false
    var syncNeedsReactions = false
    var syncNeedsComments = false

	private enum CodingKeys : CodingKey {
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

	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		id = try c.decode(String.self, forKey: .id)
		parents = try c.decode([String: [Relationship]].self, forKey: .parents)
		elementType = try c.decode(String.self, forKey: .elementType)
		bodyText = try c.decode(String.self, forKey: .bodyText)
		createdAt = try c.decode(Date.self, forKey: .createdAt)
		updatedAt = try c.decode(Date.self, forKey: .updatedAt)
		number = try c.decode(Int.self, forKey: .number)
		title = try c.decode(String.self, forKey: .title)
		url = try c.decode(URL.self, forKey: .url)
		state = try c.decode(ItemState.self, forKey: .state)
		viewerDidAuthor = try c.decode(Bool.self, forKey: .viewerDidAuthor)
		syncState = .none
	}

	func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: CodingKeys.self)
		try c.encode(id, forKey: .id)
		try c.encode(parents, forKey: .parents)
		try c.encode(elementType, forKey: .elementType)
		try c.encode(bodyText, forKey: .bodyText)
		try c.encode(createdAt, forKey: .createdAt)
		try c.encode(updatedAt, forKey: .updatedAt)
		try c.encode(number, forKey: .number)
		try c.encode(title, forKey: .title)
		try c.encode(url, forKey: .url)
		try c.encode(state, forKey: .state)
		try c.encode(viewerDidAuthor, forKey: .viewerDidAuthor)
	}

	mutating func apply(_ node: [AnyHashable:Any]) -> Bool {
		guard node.keys.count > 8 else { return false }

        syncNeedsReactions = (node["reactions"] as? [AnyHashable : Any])?["totalCount"] as? Int ?? 0 > 0
        syncNeedsComments = (node["comments"] as? [AnyHashable : Any])?["totalCount"] as? Int ?? 0 > 0

        bodyText = node["bodyText"] as? String ?? ""
		createdAt = GHDateFormatter.parseGH8601(node["createdAt"] as? String) ?? Date.distantPast
		updatedAt = GHDateFormatter.parseGH8601(node["updatedAt"] as? String) ?? Date.distantPast
		number = node["number"] as? Int ?? 0
		title = node["title"] as? String ?? ""
		url = URL(string: node["url"] as? String ?? "") ?? emptyURL
		state = ItemState(rawValue: node["state"] as? String ?? "CLOSED") ?? ItemState.closed
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

    var shouldAnnounceClosure: Bool {
        return state == .closed
    }

    func announceClosure() {
        printSummaryLine()
    }

	var commentedByMe: Bool {
		return comments.contains(where: { $0.viewerDidAuthor })
	}

	var mentionsMe: Bool {
		let myLogin = "@"+config.myUser!.login
		if bodyText.localizedCaseInsensitiveContains(myLogin) {
			return true
		}
		return comments.contains(where: { $0.body.localizedCaseInsensitiveContains(myLogin) })
	}

    var hasNewComments: Bool {
        return comments.contains(where: { $0.syncState == .new && !$0.viewerDidAuthor })
    }

	func printSummaryLine() {
        var line = "[!"
        if state == .closed {
            line += "[B*CLOSED"
        } else if syncState == .new {
            line += "[R*NEW"
        } else if hasNewComments {
            line += "[C*COMMENTED"
		} else {
			line += "[*>"
		}
        line += "*] Issue [![*\(number)*] \(title)!]"
		if let r = repo {
			line += " (\(r.nameWithOwner))"
		}
		if let a = author {
			line += " (@\(a.login))"
		}
		log(line)
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
        log(agoFormat(prefix: "        [$Created!] ", since: createdAt) + " by @" + (author?.login ?? ""))
        log(agoFormat(prefix: "        [$Updated!] ", since: updatedAt))
		if let m = milestone {
            log("      [$Milestone!] \(m.title)")
		}
		log("            [$URL!] \(url.absoluteString)")
		log()

		if commandLineArgument(matching: "-body") != nil {
			let b = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
			if b.count > 0 {
				log("[!Body!]")
                log(b, unformatted: true)
				log()
			}
		}

		if commandLineArgument(matching: "-comments") != nil {
			let co = comments.sorted(by: { $0.createdAt < $1.createdAt })
			if !co.isEmpty {
				for c in co {
					c.printDetails()
				}
				log()
			}
        }
    }

	var comments: [Comment] {
		return children(field: "comments")
	}

	var reactions: [Reaction] {
		return children(field: "reactions")
	}

	var labels: [Label] {
		return children(field: "labels")
	}

	var assignees: [User] {
		return children(field: "assignees")
	}

	var milestone: Milestone? {
		return children(field: "milestone").first
	}

	var author: User? {
		return children(field: "author").first
	}

	var repo: Repo? {
		if let repoId = parents["Repo:issues"]?.first?.parentId {
			return Repo.allItems[repoId]
		}
		return nil
	}
	
	static let fragment = Fragment(name: "issueFields", on: "Issue", fields: [
		Field(name: "id"),
		Field(name: "bodyText"),
		Field(name: "createdAt"),
		Field(name: "updatedAt"),
		Field(name: "number"),
		Field(name: "title"),
		Field(name: "url"),
		Field(name: "state"),
		Field(name: "viewerDidAuthor"),

		Group(name: "milestone", fields: [Milestone.fragment]),
		Group(name: "author", fields: [User.fragment]),
		Group(name: "labels", fields: [Label.fragment], usePaging: true),
		Group(name: "assignees", fields: [User.fragment], usePaging: true),
        Group(name: "reactions", fields: [Field(name: "totalCount")]),
        Group(name: "comments", fields: [Field(name: "totalCount")]),
		])

    static let reactionsFragment = Fragment(name: "IssueReactionFragment", on: "Issue", fields: [
        Field(name: "id"), // not using fragment, no need to re-parse
        Group(name: "reactions", fields: [Reaction.fragment], usePaging: true)
        ])

    static let commentsFragment = Fragment(name: "IssueCommentsFragment", on: "Issue", fields: [
        Field(name: "id"), // not using fragment, no need to re-parse
        Group(name: "comments", fields: [Comment.fragmentForItems], usePaging: true)
        ])
}
