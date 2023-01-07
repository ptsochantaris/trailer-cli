//
//  Reaction.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

struct Reaction: Item {
    var id: String
    var parents: [String: LinkedList<Relationship>]
    var syncState: SyncState
    var elementType: String

    var content = ""
    static let idField = "id"

    static var allItems = [String: Reaction]()

    private enum CodingKeys: CodingKey {
        case id
        case parents
        case elementType
        case content
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        parents = try c.decode([String: LinkedList<Relationship>].self, forKey: .parents)
        elementType = try c.decode(String.self, forKey: .elementType)
        content = try c.decode(String.self, forKey: .content)
        syncState = .none
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(parents, forKey: .parents)
        try c.encode(elementType, forKey: .elementType)
        try c.encode(content, forKey: .content)
    }

    mutating func apply(_ node: [AnyHashable: Any]) -> Bool {
        guard node.keys.count >= 1 else { return false }
        content = node["content"] as? String ?? ""
        return true
    }

    init?(id: String, type: String, node: [AnyHashable: Any]) {
        self.id = id
        parents = [String: LinkedList<Relationship>]()
        elementType = type
        syncState = .new
        if !apply(node) {
            return nil
        }
    }

    var user: User? {
        children(field: "user").first
    }

    mutating func setChildrenSyncStatus(_ status: SyncState) {
        if var u = user {
            u.setSyncStatus(status, andChildren: true)
            User.allItems[u.id] = u
        }
    }

    var emoji: String {
        switch content {
        case "THUMBS_UP": return "👍"
        case "THUMBS_DOWN": return "👎"
        case "LAUGH": return "😄"
        case "HOORAY": return "🎉"
        case "CONFUSED": return "😕"
        case "HEART": return "❤️"
        case "ROCKET": return "🚀"
        default:
            return "?"
        }
    }

    static let fragment = Fragment(name: "reactions", on: "Reaction", elements: [
        Field.id,
        Field(name: "content"),
        Group(name: "user", fields: [User.fragment])
    ])
}
