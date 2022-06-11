//
//  Status.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

enum StatusState: String, Codable {
    case expected, error, failure, pending, success, empty, neutral, actionRequired, cancelled, skipped
    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "expected": self = .expected
        case "failure": self = .failure
        case "pending": self = .pending
        case "success": self = .success
        case "neutral": self = .neutral
        case "action_required": self = .actionRequired
        case "cancelled": self = .cancelled
        case "skipped": self = .skipped
        case "": self = .empty
        default:
            self = .error
        }
    }
}

struct Status: Item {
    var id: String
    var parents: [String: [Relationship]]
    var syncState: SyncState
    var elementType: String

    static var allItems = [String: Status]()
    static let idField = "id"

    var context = ""
    var createdAt = Date.distantPast
    var description = ""
    var state = StatusState.expected
    var targetUrl = emptyURL

    private enum CodingKeys: CodingKey {
        case id
        case parents
        case elementType
        case context
        case createdAt
        case description
        case state
        case targetUrl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        parents = try c.decode([String: [Relationship]].self, forKey: .parents)
        elementType = try c.decode(String.self, forKey: .elementType)
        context = try c.decode(String.self, forKey: .context)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        description = try c.decode(String.self, forKey: .description)
        state = try c.decode(StatusState.self, forKey: .state)
        targetUrl = try c.decode(URL.self, forKey: .targetUrl)
        syncState = .none
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(parents, forKey: .parents)
        try c.encode(elementType, forKey: .elementType)
        try c.encode(context, forKey: .context)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(description, forKey: .description)
        try c.encode(state, forKey: .state)
        try c.encode(targetUrl, forKey: .targetUrl)
    }

    mutating func apply(_ node: [AnyHashable: Any]) -> Bool {
        guard node.keys.count > 6 else { return false }

        createdAt = GHDateFormatter.parseGH8601(node["createdAt"] as? String) ?? .distantPast
        targetUrl = URL(string: node["targetUrl"] as? String ?? "") ?? emptyURL

        if let nodeContext = node["context"] as? String {
            context = nodeContext
            state = StatusState(rawValue: node["state"] as? String ?? "EXPECTED") ?? .expected
            description = node["description"] as? String ?? ""
        } else {
            context = Notifications.Notification.formatter.string(from: createdAt)
            state = StatusState(rawValue: node["conclusion"] as? String ?? "EXPECTED") ?? .expected
            description = node["name"] as? String ?? ""
        }
        return true
    }

    var pullRequest: PullRequest? {
        if let parentId = parents["PullRequest:contexts"]?.first?.parentId {
            return PullRequest.allItems[parentId]
        }
        return nil
    }

    mutating func setChildrenSyncStatus(_: SyncState) {}

    init?(id: String, type: String, node: [AnyHashable: Any]) {
        self.id = id
        parents = [String: [Relationship]]()
        elementType = type
        syncState = .new
        if !apply(node) {
            return nil
        }
    }

    static var fragmentForStatus = Fragment(name: "statusFields", on: "StatusContext", elements: [
        Field.id,
        Field(name: "context"),
        Field(name: "description"),
        Field(name: "state"),
        Field(name: "targetUrl"),
        Field(name: "createdAt")
    ])

    static let fragmentForCheck = Fragment(name: "checkFields", on: "CheckRun", elements: [
        Field.id,
        Field(name: "name"),
        Field(name: "conclusion"),
        Field(name: "startedAt"),
        Field(name: "completedAt"),
        Field(name: "permalink")
    ])
}
