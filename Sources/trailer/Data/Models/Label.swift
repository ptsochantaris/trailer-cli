//
//  Review.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

struct Label: Item {
    var id: String
    var parents: [String: LinkedList<Relationship>]
    var syncState = SyncState.none
    var elementType: String

    static var allItems = [String: Label]()
    static let idField = "name"

    var color = ""

    private enum CodingKeys: CodingKey {
        case id
        case parents
        case elementType
        case color
    }

    mutating func apply(_ node: JSON) -> Bool {
        guard node.keys.count > 1 else { return false }
        color = node["color"] as? String ?? ""
        return true
    }

    init?(id: String, type: String, node: JSON) {
        self.id = id
        parents = [String: LinkedList<Relationship>]()
        elementType = type
        syncState = .new
        if !apply(node) {
            return nil
        }
    }

    var issue: Issue? {
        if let parentId = parents["Issue:labels"]?.first?.parentId {
            return Issue.allItems[parentId]
        }
        return nil
    }

    var pullRequest: PullRequest? {
        if let parentId = parents["PullRequest:labels"]?.first?.parentId {
            return PullRequest.allItems[parentId]
        }
        return nil
    }

    mutating func setChildrenSyncStatus(_: SyncState) {}

    static let fragment = Fragment(name: "labelFields", on: "Label", elements: [
        Field(name: "name"),
        Field(name: "color")
    ])
}
