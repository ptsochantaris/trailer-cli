//
//  Data.swift
//  trailer
//
//  Created by Paul Tsochantaris on 21/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation
import Dispatch

enum NotificationMode {
    case none, standard, consoleCommentsAndReviews
}

struct DB {
	
	private static let allTypes: [Databaseable.Type] = [
        Org.self,
        Repo.self,
        Issue.self,
        PullRequest.self,
        Milestone.self,
        Status.self,
        ReviewRequest.self,
        Label.self,
        Comment.self,
        Review.self,
        Reaction.self,
        User.self,
	]

	static private var parents2fields2children = [String: [String: [String]]]()

	static func idsForChildren(of itemId: String, field: String) -> [String]? {
		return parents2fields2children[itemId]?[field]
	}

	static func addChild(id: String, to parent: Parent) {
		let fieldName = parent.field
		let parentId = parent.item.id
		var field2children = parents2fields2children[parentId] ?? [String: [String]]()
		var listOfChildren = field2children[fieldName] ?? [String]()
		listOfChildren.append(id)
		field2children[fieldName] = listOfChildren
		parents2fields2children[parentId] = field2children
	}

	static func removeChild(id: String, from parentId: String, field: String) {
		var field2children = parents2fields2children[parentId] ?? [String: [String]]()
		let listOfChildren = field2children[field]?.filter { $0 != id }
		field2children[field] = (listOfChildren?.count == 0) ? nil : listOfChildren
		parents2fields2children[parentId] = field2children
	}

	static func load() {
		log(level: .debug, "Loading DB...")
		let loadingQueue = DispatchQueue.global(qos: .userInteractive)
		loadingQueue.sync {
			let e = JSONDecoder()
			DispatchQueue.concurrentPerform(iterations: allTypes.count+1) { iteration in
				if iteration == allTypes.count {
					loadRelationships(using: e)
				} else {
					allTypes[iteration].loadAll(using: e)
				}
			}
		}
		log(level: .verbose, "Loaded DB")

		config.myUser = User.allItems.values.first { $0.isMe }
		if config.myUser != nil {
			log(level: .verbose, "API user is [*\(config.myLogin)*]")
		}
	}

    static func save(purgeUntouchedItems: Bool, notificationMode: NotificationMode) {

        log(level: .debug, "Processing Announcements...")
        allTypes.forEach { $0.processAnnouncements(notificationMode: notificationMode) }

        if purgeUntouchedItems {
			log(level: .debug, "Purging stale items...")
			allTypes.forEach { $0.purgeUntouchedItems() }
			allTypes.forEach { $0.purgeStaleRelationships() }
		}

		log(level: .debug, "Saving DB...")
		let savingQueue = DispatchQueue.global(qos: .userInteractive)
		savingQueue.sync {
			let e = JSONEncoder()
			DispatchQueue.concurrentPerform(iterations: allTypes.count+1) { iteration in
				if iteration == allTypes.count {
					saveRelationships(using: e)
				} else {
					allTypes[iteration].saveAll(using: e)
				}
			}
		}
		log(level: .verbose, "Saved DB to \(config.saveLocation.path)/")
	}

	static func loadRelationships(using decoder: JSONDecoder) {
		parents2fields2children.removeAll()
		let l = relationshipsPath
		if FileManager.default.fileExists(atPath: l.path) {
			do {
				let d = try Data(contentsOf: l)
				parents2fields2children = try decoder.decode([String: [String:[String]]].self, from: d)
			} catch {
				log("Could not load data for relationships")
			}
		}

	}

	static var relationshipsPath: URL {
		return config.saveLocation.appendingPathComponent("relationships.json", isDirectory: false)
	}

	static func saveRelationships(using encoder: JSONEncoder) {
		let c = try! encoder.encode(parents2fields2children)
		let l = relationshipsPath
		let f = FileManager.default
		if f.fileExists(atPath: l.path) {
			try! f.removeItem(at: l)
		}
		try! c.write(to: l)
	}

}
