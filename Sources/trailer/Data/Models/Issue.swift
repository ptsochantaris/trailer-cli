//
//  Issue.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

struct Issue: Item, Announceable, Closeable, Sortable {
	var id: String
	var parents: [String: [Relationship]]
	var syncState: SyncState
	var elementType: String

	static var allItems = [String:Issue]()
	static let idField = "id"

	var bodyText = ""
	var createdAt = Date.distantPast
	var updatedAt = Date.distantPast
	var number: Int = 0
	var title = ""
	var url = emptyURL
	var state = ItemState.closed
	var viewerDidAuthor = false
    var syncNeedsReactions = false

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
		return 1
	}

	var headRefName: String {
		return ""
	}

    var shouldAnnounceClosure: Bool {
        return state == .closed
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
		return comments.contains { $0.mentionsMe }
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

	func commentsInclude(text: String) -> Bool {
		return comments.contains { $0.includes(text: text) }
	}

	func printSummaryLine() {
		printSummaryLine(closing : false)
	}
	func printSummaryLine(closing: Bool) {
		var components = [String]()
        var line = "[!"
        if closing && state == .closed {
            line += "[B*CLOSED"
        } else if syncState == .new {
            line += "[R*NEW"
        } else if hasNewComments {
            line += "[C*COMMENTED"
		} else {
			line += "[*>"
		}
        line += "*]"
		components.append(line)

		if listFieldsDefinition.type {
			components.append("Issue")
		}
		if listFieldsDefinition.number {
			components.append("[*\(number)*]")
		}
		if listFieldsDefinition.title {
			components.append(title)
		}

		let x = components.popLast()! + "!]"
		components.append(x)

		if listFieldsDefinition.labels, !labels.isEmpty {
			let l = labels.map { $0.id }.joined(separator: "] [")
			components.append("[\(l)]")
		}
		if listFieldsDefinition.repo, let r = repo {
			components.append("(\(r.nameWithOwner))")
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
			for r in react {
				if let u = r.user {
					log("\(r.emoji)  - @\(u.login)")
				}
			}
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
	
	static let fragment = Fragment(name: "issueFields", on: "Issue", elements: [
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
		])

    static let reactionsFragment = Fragment(name: "IssueReactionFragment", on: "Issue", elements: [
        Field(name: "id"), // not using fragment, no need to re-parse
        Group(name: "reactions", fields: [Reaction.fragment], usePaging: true)
        ])

    static let commentsFragment = Fragment(name: "IssueCommentsFragment", on: "Issue", elements: [
        Field(name: "id"), // not using fragment, no need to re-parse
        Group(name: "comments", fields: [Comment.fragmentForItems], usePaging: true)
        ])

	static var fragmentWithComments: Fragment {
		var f = fragment
		f.addField(Group(name: "comments", fields: [Comment.fragmentForItems], usePaging: true))
		return f
	}
}
