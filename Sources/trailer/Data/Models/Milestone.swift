//
//  Milestone.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

struct Milestone: Item {
    var id: String
    var parents: [String: [Relationship]]
    var syncState: SyncState
    var elementType: String

    static var allItems = [String: Milestone]()
    static let idField = "id"

    var title = ""

    private enum CodingKeys: CodingKey {
        case id
        case parents
        case elementType
        case title
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        parents = try c.decode([String: [Relationship]].self, forKey: .parents)
        elementType = try c.decode(String.self, forKey: .elementType)
        syncState = .none
        title = try c.decode(String.self, forKey: .title)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(parents, forKey: .parents)
        try c.encode(elementType, forKey: .elementType)
        try c.encode(title, forKey: .title)
    }

    mutating func apply(_ node: [AnyHashable: Any]) -> Bool {
        guard node.keys.count > 1 else { return false }
        title = node["title"] as? String ?? ""
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

    mutating func setChildrenSyncStatus(_: SyncState) {}

    static let fragment = Fragment(name: "milestoneFields", on: "Milestone", elements: [
        Field.id,
        Field(name: "title")
    ])
}
