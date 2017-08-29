//
//  Data.swift
//  trailer
//
//  Created by Paul Tsochantaris on 21/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

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
		let e = JSONDecoder()
		allTypes.forEach({ $0.loadAll(using: e) })
		log(level: .verbose, "Loaded DB")
		config.myUser = User.allItems.values.first { $0.isMe }
		if let me = config.myUser {
			log(level: .verbose, "API user is [*@\(me.login)*]")
		}
	}

	static func save(purgeUntouchedItems: Bool) {
        log(level: .debug, "Processing Announcements...")
        allTypes.forEach { $0.processAnnouncements() }

        if purgeUntouchedItems {
			log(level: .debug, "Purging stale items...")
			allTypes.forEach { $0.purgeUntouchedItems() }
			allTypes.forEach { $0.purgeStaleRelationships() }
		}

		log(level: .debug, "Saving DB...")
		let e = JSONEncoder()
		allTypes.forEach { $0.saveAll(using: e) }
		log(level: .verbose, "Saved DB to \(config.saveLocation.path)/")
	}
}
