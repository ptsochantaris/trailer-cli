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
    var parents: [String: [Relationship]]
    var syncState: SyncState
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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        parents = try c.decode([String: [Relationship]].self, forKey: .parents)
        elementType = try c.decode(String.self, forKey: .elementType)
        color = try c.decode(String.self, forKey: .color)
        syncState = .none
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(parents, forKey: .parents)
        try c.encode(elementType, forKey: .elementType)
        try c.encode(color, forKey: .color)
    }

    mutating func apply(_ node: [AnyHashable: Any]) -> Bool {
        guard node.keys.count > 1 else { return false }
        color = node["color"] as? String ?? ""
        return true
    }

    init?(id: String, type: String, node: [AnyHashable: Any]) {
        self.id = id
        parents = [String: [Relationship]]()
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
