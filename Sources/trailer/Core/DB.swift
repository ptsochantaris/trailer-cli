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

	static func load() {
		log(level: .debug, "Loading DB...")
		let loadingQueue = DispatchQueue.global(qos: .userInteractive)
		loadingQueue.sync {
			let e = JSONDecoder()
			DispatchQueue.concurrentPerform(iterations: allTypes.count) { iteration in
				allTypes[iteration].loadAll(using: e)
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
			DispatchQueue.concurrentPerform(iterations: allTypes.count) { iteration in
				allTypes[iteration].saveAll(using: e)
			}
		}
		log(level: .verbose, "Saved DB to \(config.saveLocation.path)/")
	}
}
