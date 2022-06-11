//
//  ReviewRequest.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

struct ReviewRequest: Item {
    var id: String
    var parents: [String: [Relationship]]
    var syncState: SyncState
    var elementType: String

    static var allItems = [String: ReviewRequest]()
    static let idField = "id"

    private enum CodingKeys: CodingKey {
        case id
        case parents
        case elementType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        parents = try c.decode([String: [Relationship]].self, forKey: .parents)
        elementType = try c.decode(String.self, forKey: .elementType)
        syncState = .none
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(parents, forKey: .parents)
        try c.encode(elementType, forKey: .elementType)
    }

    mutating func apply(_: [AnyHashable: Any]) -> Bool {
        true
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

    mutating func setChildrenSyncStatus(_ status: SyncState) {
        if var u = reviewer {
            u.setSyncStatus(status, andChildren: true)
            User.allItems[u.id] = u
        }
    }

    var reviewer: User? {
        children(field: "requestedReviewer").first
    }

    var pullRequest: PullRequest? {
        if let parentId = parents["PullRequest:reviewRequests"]?.first?.parentId {
            return PullRequest.allItems[parentId]
        }
        return nil
    }

    static let fragment = Fragment(name: "reviewRequestFields", on: "ReviewRequest", elements: [
        Field.id,
        Group(name: "requestedReviewer", fields: [User.fragment])
    ])
}
