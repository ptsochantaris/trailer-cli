//
//  User.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

struct User: Item {
    var id: String
    var parents: [String: LinkedList<Relationship>]
    var syncState = SyncState.none
    var elementType: String

    var avatarUrl = emptyURL
    var login = ""
    var isMe = false

    static var allItems = [String: User]()
    static let idField = "id"

    private enum CodingKeys: CodingKey {
        case id
        case login
        case parents
        case elementType
        case avatarUrl
        case isMe
    }

    mutating func apply(_ node: JSON) -> Bool {
        guard node.keys.count > 2 else { return false }
        avatarUrl = URL(string: node["avatarUrl"] as? String ?? "") ?? emptyURL
        login = node["login"] as? String ?? ""
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

    mutating func setChildrenSyncStatus(_: SyncState) {}

    static let fragment = Fragment(name: "userFields", on: "User", elements: [
        Field.id,
        Field(name: "login"),
        Field(name: "avatarUrl")
    ])
}
