//
//  Item.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

protocol Item: Identifiable, Databaseable, Equatable {
	static var allItems: [String:Self] { get set }
	static func parse(parent: Parent?, elementType: String, node: [AnyHashable : Any], level: Int) -> Self?
	static var idField: String { get }

	init?(id: String, type: String, node: [AnyHashable:Any])

	var parents: [String: [Relationship]] { get set }
	mutating func apply(_ node: [AnyHashable:Any]) -> Bool
	mutating func assumeChildrenSynced()
}

extension Item {

	static func assumeSynced(andChildren: Bool, limitToIds: [String]? = nil) {
		allItems = allItems.mapValues { item in
			if let l = limitToIds, !l.contains(item.id) {
				return item
			} else {
				var i = item
				i.assumeSynced(andChildren: andChildren)
				return i
			}
		}
	}

	mutating func assumeSynced(andChildren: Bool) {
		syncState = .updated
		parents = parents.mapValues { relationshipsToAType -> [Relationship] in
			return relationshipsToAType.map { var n = $0; n.syncState = .updated; return n }
		}
		if andChildren {
			assumeChildrenSynced()
		}
	}

	private static var dataURL: URL {
		return config.saveLocation.appendingPathComponent("\(typeName).json", isDirectory: false)
	}

	private static func checkItemExists(type: String, id: String) -> Bool {
		switch type {
		case "Org": return Org.allItems.keys.contains(id)
		case "Repo": return Repo.allItems.keys.contains(id)
		case "Comment": return Comment.allItems.keys.contains(id)
		case "User": return User.allItems.keys.contains(id)
		case "Reaction": return Reaction.allItems.keys.contains(id)
		case "PullRequest": return PullRequest.allItems.keys.contains(id)
		case "Issue": return Issue.allItems.keys.contains(id)
		case "Label": return Label.allItems.keys.contains(id)
		case "Review": return Review.allItems.keys.contains(id)
		case "ReviewRequest": return ReviewRequest.allItems.keys.contains(id)
		case "Status": return Status.allItems.keys.contains(id)
		case "Milestone": return Milestone.allItems.keys.contains(id)
		default: return false
		}
	}

	static func purgeStaleRelationships() {
		allItems = allItems.mapValues { item in
			var newItem = item
			for (relationshipKey, previousRelationships) in item.parents {

				let P = relationshipKey.split(separator: ":")
				let parentTypeName = String(P.first!)
				let parentField = String(P.last!)

				newItem.parents[relationshipKey] = previousRelationships.flatMap { relationship -> Relationship? in
					if relationship.syncState == .none {
						log(level: .debug, "Removing stale relationship from \(item.typeName) \(item.id) to parent ID \(relationship.parentId)")
						DB.removeChild(id: item.id, from: relationship.parentId, field: parentField)
						return nil
					} else if checkItemExists(type: parentTypeName, id: relationship.parentId) { // object actually exists
						var newRelationship = relationship
						newRelationship.syncState = .none
						return newRelationship
					} else {
						log(level: .debug, "Removing relationship from \(item.typeName) \(item.id) to parent ID \(relationship.parentId) which no longer exists")
						DB.removeChild(id: item.id, from: relationship.parentId, field: parentField)
						return nil
					}
				}
			}
			return newItem
		}
	}

    static func purgeUntouchedItems() {
		
		var purgedItemCount = 0
		for id in allItems.keys {
            guard let item = allItems[id] else { continue }
            let s = item.syncState
			if s == .none {
				log(level: .debug, "\(typeName) \(id) no longer present in server data")
				purgedItemCount += 1
				DB.removeParent(item)
            } else if s == .updated, let i = item as? Closeable, i.shouldAnnounceClosure {
                log(level: .debug, "\(typeName) \(id) is closed or merged, will remove")
                i.announceClosure()
                purgedItemCount += 1
				DB.removeParent(item)
            }
		}

		if purgedItemCount > 0 {
			log(level: .verbose, "Purged \(purgedItemCount) \(typeName) item(s) after update")
		}
	}

    static func processAnnouncements(notificationMode: NotificationMode) {
        allItems.values.forEach {
            if let i = $0 as? Announceable {
                i.announceIfNeeded(notificationMode: notificationMode)
            }
        }
    }

	static func saveAll(using encoder: JSONEncoder) {

		var newItemCount = 0
		allItems = allItems.mapValues {
			if $0.syncState == .new {
                newItemCount += 1
				log(level: .debug, "Created \(typeName) \($0.id)")
                var new = $0
                new.syncState = .none
				return new
			} else {
				return $0
			}
		}
		if newItemCount > 0 {
			log(level: .verbose, "Created \(newItemCount) \(typeName) item(s) after update")
		}

		let c = try! encoder.encode(allItems)
		let l = dataURL
		let f = FileManager.default
		if f.fileExists(atPath: l.path) {
			try! f.removeItem(at: l)
		}
		try! c.write(to: l)
	}

	static func loadAll(using decoder: JSONDecoder) {
		allItems.removeAll()
		let l = dataURL
		if FileManager.default.fileExists(atPath: l.path) {
			do {
				let d = try Data(contentsOf: l)
				allItems = try decoder.decode([String:Self].self, from: d)
			} catch {
				log("Could not load data for type [*\(typeName)*]")
				allItems = [String:Self]()
			}
		}
	}

	mutating func makeChild(of parent: Parent, indent level: Int, quiet: Bool = false) {
		let relationship = Relationship(to: parent)
		let storedField = "\(parent.item.typeName):\(parent.field)"
		if var existingRelationships = parents[storedField] {
			if let indexOfExisting = existingRelationships.index(where: { $0 == relationship }) {
				existingRelationships[indexOfExisting] = relationship
				parents[storedField] = existingRelationships
				if !quiet { log(level: .debug, indent: level, "Already linked to this parent in relationship '\(parent.field)'") }
			} else {
				existingRelationships.append(relationship)
				DB.addChild(id: id, to: parent)
				parents[storedField] = existingRelationships
				if !quiet { log(level: .debug, indent: level, "Adding another link to the existing parent(s) in relationship '\(parent.field)'") }
			}
		} else {
			parents[storedField] = [relationship]
			DB.addChild(id: id, to: parent)
			if !quiet { log(level: .debug, indent: level, "Linking to parent through relationship '\(parent.field)'") }
		}
	}

	static func parse(parent: Parent?, elementType: String, node: [AnyHashable : Any], level: Int) -> Self? {
		guard let id = node[Self.idField] as? String else { return nil }

		if var ret = existingItem(with: id) {
			log(level: .debug, indent: level, "Existing \(typeName) ID \(ret.id)")
			if let parent = parent {
				ret.makeChild(of: parent, indent: level)
			}
			if !ret.apply(node) {
				log(level: .debug, indent: level, "Was placeholder data, skipped update")
			}
            if ret.syncState != .new {
                ret.syncState = .updated
            }
			allItems[id] = ret
			return ret
		} else {
			if var new = Self.init(id: id, type: elementType, node: node) {
				log(level: .debug, indent: level, "+ \(typeName): \(id)")
				if let parent = parent {
					new.makeChild(of: parent, indent: level)
				}
				allItems[id] = new
				return new
			} else {
				log(level: .debug, indent: level, "Was placeholder data, skipping creation")
				return nil
			}
		}
	}

	static func existingItem(with id: String) -> Self? {
		return Self.allItems[id]
	}

	func children<T: Item>(field: String) -> [T] {
		if let childrenIds = DB.idsForChildren(of: id, field: field) {
			return childrenIds.flatMap { T.allItems[$0] }
		} else {
			return []
		}
	}

	static func ==(lhs: Self, rhs: Self) -> Bool {
		return lhs.id == rhs.id
	}
}

