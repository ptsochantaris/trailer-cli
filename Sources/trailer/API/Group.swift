
//
//  Group.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

enum PagingStyle {
    case none, onlyLast, largePage, smallPage
}

struct Group: Ingesting {
    let name: String
    let fields: [Element]
    private let paging: PagingStyle
    private let extraParams: [String: String]?
    private var lastCursor: String?

    init(name: String, fields: [Element], extraParams: [String: String]? = nil, paging: PagingStyle = .none) {
        self.name = name
        self.fields = fields
        self.paging = paging
        self.extraParams = extraParams
    }

    init(group: Group, name: String? = nil, lastCursor: String? = nil) {
        self.name = name ?? group.name
        fields = group.fields
        paging = group.paging
        extraParams = group.extraParams
        self.lastCursor = lastCursor
    }

    var queryText: String {
        var query = name
        var brackets = [String]()

        switch paging {
        case .none:
            break
        case .onlyLast:
            brackets.append("last: 1")
        case .largePage:
            brackets.append("first: 100")
            if let lastCursor {
                brackets.append("after: \"\(lastCursor)\"")
            }
        case .smallPage:
            brackets.append("first: 20")
            if let lastCursor {
                brackets.append("after: \"\(lastCursor)\"")
            }
        }

        if let e = extraParams {
            for (k, v) in e {
                brackets.append("\(k): \(v)")
            }
        }

        if brackets.hasItems {
            query += "(" + brackets.joined(separator: ", ") + ")"
        }

        let fieldsText = "__typename " + fields.map(\.queryText).joined(separator: " ")

        if paging == .none {
            query += " { " + fieldsText + " }"
        } else {
            query += " { edges { node { " + fieldsText + " } cursor } pageInfo { hasNextPage } }"
        }

        return query
    }

    var fragments: LinkedList<Fragment> {
        let res = LinkedList<Fragment>()
        for f in fields {
            res.append(contentsOf: f.fragments)
        }
        return res
    }

    private func checkFields(query: Query, hash: [AnyHashable: Any], parent: Parent?, level: Int) -> LinkedList<Query> {
        let thisObject: Identifiable?
        if let o = Group.parse(parent: parent, info: hash, level: level) {
            thisObject = o
        } else {
            thisObject = parent?.item
        }

        let extraQueries = LinkedList<Query>()

        for field in fields {
            if let field = field as? Fragment {
                let p = Parent(item: thisObject, field: parent?.field)
                let newQueries = field.ingest(query: query, pageData: hash, parent: p, level: level + 1)
                extraQueries.append(contentsOf: newQueries)
            } else if let field = field as? Ingesting, let fieldData = hash[field.name] {
                let p = Parent(item: thisObject, field: field.name)
                let newQueries = field.ingest(query: query, pageData: fieldData, parent: p, level: level + 1)
                extraQueries.append(contentsOf: newQueries)
            }
        }

        return extraQueries
    }

    func ingest(query: Query, pageData: Any, parent: Parent?, level: Int) -> LinkedList<Query> {
        let extraQueries = LinkedList<Query>()

        if let hash = pageData as? [AnyHashable: Any] { // data was a dictionary
            if let edges = hash["edges"] as? [[AnyHashable: Any]] {
                log(level: .debug, indent: level, "Ingesting paged group \(name)")
                var latestCursor: String?
                for e in edges {
                    if let node = e["node"] as? [AnyHashable: Any] {
                        let newQueries = checkFields(query: query, hash: node, parent: parent, level: level + 1)
                        extraQueries.append(contentsOf: newQueries)
                    }
                    latestCursor = e["cursor"] as? String
                }
                if let latestCursor, let pageInfo = hash["pageInfo"] as? [AnyHashable: Any], let hasNextPage = pageInfo["hasNextPage"] as? Bool, hasNextPage {
                    var newGroup = self
                    newGroup.lastCursor = latestCursor
                    let nextPage = Query(name: query.name, rootElement: newGroup, parent: parent, subQuery: true)
                    extraQueries.append(nextPage)
                }

            } else {
                log(level: .debug, indent: level, "Ingesting group \(name)")
                let newQueries = checkFields(query: query, hash: hash, parent: parent, level: level + 1)
                extraQueries.append(contentsOf: newQueries)
            }

        } else if let nodes = pageData as? [[AnyHashable: Any]] { // data was an array of dictionaries with no paging info
            log(level: .debug, indent: level, "Ingesting list of groups \(name)")
            for node in nodes {
                let newQueries = checkFields(query: query, hash: node, parent: parent, level: level + 1)
                extraQueries.append(contentsOf: newQueries)
            }
        }

        if extraQueries.count > 0 {
            log(level: .debug, indent: level, "\(name) will need further paging")
        }
        return extraQueries
    }

    private static func parse(parent: Parent?, info: [AnyHashable: Any], level: Int) -> Identifiable? {
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
            case "CheckRun", "StatusContext":
                return Status.parse(parent: parent, elementType: typeName, node: info, level: level)
            case "Milestone":
                return Milestone.parse(parent: parent, elementType: typeName, node: info, level: level)
            case "Organization":
                return Org.parse(parent: parent, elementType: typeName, node: info, level: level)
            case "Bot", "CheckSuite", "Commit", "PullRequestCommit", "PullRequestReviewCommentConnection", "ReactionConnection", "Status":
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
