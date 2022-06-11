//
//  Relationship.swift
//  trailer
//
//  Created by Paul Tsochantaris on 28/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

struct Relationship: Codable, Equatable {
    let parentId: String
    var syncState: SyncState

    private enum CodingKeys: CodingKey {
        case parentId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        parentId = try c.decode(String.self, forKey: .parentId)
        syncState = .none
    }

    init(to parent: Parent) {
        parentId = parent.item.id
        syncState = .new
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(parentId, forKey: .parentId)
    }

    static func == (lhs: Relationship, rhs: Relationship) -> Bool {
        lhs.parentId == rhs.parentId
    }
}
