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
	var parents: [String: [Relationship]]
	var syncState: SyncState
	var elementType: String

	var avatarUrl = emptyURL
	var login: String = ""
	var isMe = false

	static var allItems = [String:User]()
	static var idField = "id"

	private enum CodingKeys : CodingKey {
		case id
		case login
		case parents
		case elementType
		case avatarUrl
		case isMe
	}

	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		id = try c.decode(String.self, forKey: .id)
		login = try c.decode(String.self, forKey: .login)
		parents = try c.decode([String: [Relationship]].self, forKey: .parents)
		elementType = try c.decode(String.self, forKey: .elementType)
		elementType = try c.decode(String.self, forKey: .elementType)
		avatarUrl = try c.decode(URL.self, forKey: .avatarUrl)
		isMe = try c.decode(Bool.self, forKey: .isMe)
		syncState = .none
	}

	func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: CodingKeys.self)
		try c.encode(id, forKey: .id)
		try c.encode(login, forKey: .login)
		try c.encode(parents, forKey: .parents)
		try c.encode(elementType, forKey: .elementType)
		try c.encode(avatarUrl, forKey: .avatarUrl)
		try c.encode(isMe, forKey: .isMe)
	}

	mutating func apply(_ node: [AnyHashable:Any]) -> Bool {
		guard node.keys.count > 2 else { return false }
		avatarUrl = URL(string: node["avatarUrl"] as? String ?? "") ?? emptyURL
		login = node["login"] as? String ?? ""
		return true
	}

	init?(id: String, type: String, parents: [String: [Relationship]], node: [AnyHashable:Any]) {
		self.id = id
		self.parents = parents
		self.elementType = type
		syncState = .new
		if !apply(node) {
			return nil
		}
	}

	static let fragment = Fragment(name: "userFields", on: "User", fields: [
		Field(name: "id"),
		Field(name: "login"),
		Field(name: "avatarUrl")
		])
}

