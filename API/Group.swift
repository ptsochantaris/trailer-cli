
//
//  Group.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

struct Group: Ingesting {

	var name: String
	var fields: [Element]
	private let usePaging: Bool
	private let onlyLast: Bool
	private let extraParams: [String: String]?
	private var lastCursor: String?
	
	init(name: String, fields: [Element], extraParams: [String: String]? = nil, usePaging: Bool = false, onlyLast: Bool = false) {
		self.name = name
		self.fields = fields
		self.usePaging = usePaging
		self.onlyLast = onlyLast
		self.extraParams = extraParams
	}
	
	var queryText: String {
		
		var query = name
		var brackets = [String]()
		
		if usePaging {
			if onlyLast {
				brackets.append("last: 1")
			} else {
				brackets.append("first: 100")
				if let lastCursor = lastCursor {
					brackets.append("after: \"\(lastCursor)\"")
				}
			}
		}
		
		if let e = extraParams {
			for (k, v) in e {
				brackets.append("\(k): \(v)")
			}
		}
		
		if !brackets.isEmpty {
			query += "(" + brackets.joined(separator: ", ") + ")"
		}
		
		let fieldsText = "__typename " + fields.map({$0.queryText}).joined(separator: " ")
		
		if usePaging {
			query += " { edges { node { " + fieldsText + " } cursor } pageInfo { hasNextPage } }"
		} else {
			query += " { " + fieldsText + " }"
		}
		
		return query
	}
	
	var fragments: [Fragment] {
		var res = [Fragment]()
		for f in fields {
			res.append(contentsOf: f.fragments)
		}
		return res
	}
	
	private func checkFields(query: Query, hash: [AnyHashable : Any], parent: Parent?, level: Int) -> [Query] {
		
		let thisObject: Identifiable?
		if let o = Group.parse(parent: parent, info: hash, level: level) {
			thisObject = o
		} else {
			thisObject = parent?.item
		}
		
		var extraQueries = [Query]()

		for field in fields {
			if let field = field as? Fragment {
				let p = Parent(item: thisObject, field: parent?.field)
				let newQueries = field.ingest(query: query, pageData: hash, parent: p, level: level+1)
				extraQueries.append(contentsOf: newQueries)
			} else if let field = field as? Ingesting, let fieldData = hash[field.name] {
				let p = Parent(item: thisObject, field: field.name)
				let newQueries = field.ingest(query: query, pageData: fieldData, parent: p, level: level+1)
				extraQueries.append(contentsOf: newQueries)
			}
		}

		return extraQueries
	}
	
	func ingest(query: Query, pageData: Any, parent: Parent?, level: Int) -> [Query] {

		var extraQueries = [Query]()

		if let hash = pageData as? [AnyHashable : Any] { // data was a dictionary
			if let edges = hash["edges"] as? [[AnyHashable : Any]] {
				log(level: .debug, indent: level, "Ingesting paged group \(name)")
				var latestCursor: String?
				for e in edges {
					if let node = e["node"] as? [AnyHashable : Any] {
						let newQueries = checkFields(query: query, hash: node, parent: parent, level: level+1)
						extraQueries.append(contentsOf: newQueries)
					}
					latestCursor = e["cursor"] as? String
				}
				if let latestCursor = latestCursor, let pageInfo = hash["pageInfo"] as? [AnyHashable : Any], let hasNextPage = pageInfo["hasNextPage"] as? Bool, hasNextPage {
					var newGroup = self
					newGroup.lastCursor = latestCursor
					let nextPage = Query(name: query.name, rootElement: newGroup, parent: parent, subQuery: true)
					extraQueries.append(nextPage)
				}
				
			} else {
				log(level: .debug, indent: level, "Ingesting group \(name)")
				let newQueries = checkFields(query: query, hash: hash, parent: parent, level: level+1)
				extraQueries.append(contentsOf: newQueries)
			}
			
		} else if let nodes = pageData as? [[AnyHashable : Any]] { // data was an array of dictionaries with no paging info
			log(level: .debug, indent: level, "Ingesting list of groups \(name)")
			for node in nodes {
				let newQueries = checkFields(query: query, hash: node, parent: parent, level: level+1)
				extraQueries.append(contentsOf: newQueries)
			}
		}
		
		if !extraQueries.isEmpty {
			log(level: .debug, indent: level, "\(name) will need further paging")
		}
		return extraQueries
	}

	static private func parse(parent: Parent?, info: [AnyHashable: Any], level: Int) -> Identifiable? {

		if let typeName = info["__typename"] as? String {

			if let p = parent {
				log(level: .debug, indent: level, "Scanning \(typeName) with parent \(p.item.typeName) \(p.item.id)")
			} else {
				log(level: .debug, indent: level, "Scanning \(typeName)")
			}

			switch typeName {
			case "Repository":
				return Repo.parse(parent: parent, elementType: typeName, node: info, level: level)
			case "Label":
				return Label.parse(parent: parent, elementType: typeName, node: info, level: level)
			case "PullRequest":
				return PullRequest.parse(parent: parent, elementType: typeName, node: info, level: level)
			case "Issue":
				return Issue.parse(parent: parent, elementType: typeName, node: info, level: level)
			case "IssueComment", "PullRequestReviewComment":
				return Comment.parse(parent: parent, elementType: typeName, node: info, level: level)
			case "PullRequestReview":
				return Review.parse(parent: parent, elementType: typeName, node: info, level: level)
			case "Reaction":
				return Reaction.parse(parent: parent, elementType: typeName, node: info, level: level)
			case "User":
				let u = User.parse(parent: parent, elementType: typeName, node: info, level: level)
				if parent == nil, var me = u {
					me.isMe = true
					config.myUser = me
					User.allItems[me.id] = me
					return me
				}
				return u
			case "ReviewRequest":
				return ReviewRequest.parse(parent: parent, elementType: typeName, node: info, level: level)
			case "StatusContext":
				return Status.parse(parent: parent, elementType: typeName, node: info, level: level)
			case "Milestone":
				return Milestone.parse(parent: parent, elementType: typeName, node: info, level: level)
			case "Organization":
				return Org.parse(parent: parent, elementType: typeName, node: info, level: level)
			case "ReactionConnection", "PullRequestCommit", "Commit", "Status", "Bot":
				return nil
			default:
				log(level: .debug, indent: level, "+ Warning: unhandled type '\(typeName)'")
				return nil
			}
		} else {
			log(level: .debug, indent: level, "+ Warning: no typename in info to parse")
			return nil
		}
	}
}
