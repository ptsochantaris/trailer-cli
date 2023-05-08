//
//  Repo.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

enum RepoVisibility: String, Codable {
    case hidden, visible, onlyPrs, onlyIssues
}

struct Repo: Item, Announceable {
    var id: String
    var parents: [String: LinkedList<Relationship>]
    var syncState = SyncState.none
    var elementType: String

    static var allItems = [String: Repo]()
    static let idField = "id"

    var createdAt = Date.distantPast
    var updatedAt = Date.distantPast
    var isFork = false
    var url = emptyURL
    var nameWithOwner = ""
    var visibility = RepoVisibility.visible

    private enum CodingKeys: CodingKey {
        case id
        case parents
        case elementType
        case createdAt
        case updatedAt
        case isFork
        case url
        case nameWithOwner
        case visibility
    }

    mutating func apply(_ node: JSON) -> Bool {
        guard node.keys.count > 5 else { return false }

        createdAt = GHDateFormatter.parseGH8601(node["createdAt"] as? String) ?? Date.distantPast
        updatedAt = GHDateFormatter.parseGH8601(node["updatedAt"] as? String) ?? Date.distantPast
        isFork = node["isFork"] as? Bool ?? false
        url = URL(string: node["url"] as? String ?? "") ?? emptyURL
        nameWithOwner = node["nameWithOwner"] as? String ?? ""

        return true
    }

    init?(id: String, type: String, node: JSON) {
        self.id = id
        parents = [String: LinkedList<Relationship>]()
        elementType = type
        syncState = .new
        visibility = config.defaultRepoVisibility
        if !apply(node) {
            return nil
        }
    }

    func printSummaryLine() {
        let bright = visibility != .hidden || syncState == .new

        var line = ""
        if bright { line += "[!" }
        if syncState == .new {
            line += "[R*NEW *]Repo "
        } else {
            line += "[*> *]"
        }
        line += "\(nameWithOwner)"
        if bright { line += "!]" }

        let pc = pullRequests.count
        let ic = issues.count
        if pc + ic > 0 {
            line += " ("
        }
        if pc > 0 {
            if bright { line += "[!" }
            line += "[*\(pc)*]"
            if bright { line += "!]" }
            line += " PRs"
        }
        if ic > 0 {
            if pc > 0 {
                line += ", "
            }
            if bright { line += "[!" }
            line += "[*\(ic)*]"
            if bright { line += "!]" }
            line += " Issues"
        }
        if pc + ic > 0 {
            line += ")"
        }
        switch visibility {
        case .hidden:
            line += " [Hidden]"
        case .onlyIssues:
            line += " [Issues Only]"
        case .onlyPrs:
            line += " [PRs Only]"
        case .visible:
            break
        }
        log(line)
    }

    func printDetails() {
        printSummaryLine()
    }

    var shouldSyncPrs: Bool {
        (visibility == .onlyPrs || visibility == .visible) && syncState != .none
    }

    var shouldSyncIssues: Bool {
        (visibility == .onlyIssues || visibility == .visible) && syncState != .none
    }

    func announceIfNeeded(notificationMode: NotificationMode) {
        if syncState == .new {
            switch notificationMode {
            case .consoleCommentsAndReviews, .standard:
                printSummaryLine()
            case .none:
                break
            }
        }
    }

    var pullRequests: [PullRequest] {
        children(field: "pullRequests")
    }

    var issues: [Issue] {
        children(field: "issues")
    }

    var org: Org? {
        if let id = parents["Org:repositories"]?.first?.parentId {
            return Org.allItems[id]
        }
        return nil
    }

    mutating func setChildrenSyncStatus(_ status: SyncState) {
        for p in pullRequests {
            var P = p
            P.setSyncStatus(status, andChildren: true)
            PullRequest.allItems[p.id] = P
        }
        for i in issues {
            var I = i
            I.setSyncStatus(status, andChildren: true)
            Issue.allItems[i.id] = I
        }
    }

    static let fragment = Fragment(name: "repoFields", on: "Repository", elements: [
        Field.id,
        Field(name: "nameWithOwner"),
        Field(name: "isFork"),
        Field(name: "url"),
        Field(name: "createdAt"),
        Field(name: "updatedAt")
    ])

    static let prAndIssueIdsFragment = Fragment(name: "repoFields", on: "Repository", elements: [
        Field.id,
        Group(name: "pullRequests", fields: [Field.id], extraParams: ["states": "OPEN"], paging: .largePage),
        Group(name: "issues", fields: [Field.id], extraParams: ["states": "OPEN"], paging: .largePage)
    ])

    static let prIdsFragment = Fragment(name: "repoFields", on: "Repository", elements: [
        Field.id,
        Group(name: "pullRequests", fields: [Field.id], extraParams: ["states": "OPEN"], paging: .largePage)
    ])

    static let issueIdsFragment = Fragment(name: "repoFields", on: "Repository", elements: [
        Field.id,
        Group(name: "issues", fields: [Field.id], extraParams: ["states": "OPEN"], paging: .largePage)
    ])
}
