//
//  Actions-Update.swift
//  trailer
//
//  Created by Paul Tsochantaris on 26/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation
import Dispatch

enum UpdateType {
	case all, repos, prs, issues, comments, reactions
}

extension Actions {

	static private func successOrAbort(_ query: Query) {
		successOrAbort([query])
	}

	static private func successOrAbort(_ queries: [Query]) {

		var success = true
		let group = DispatchGroup()
		for q in queries {
			group.enter()
			q.run { s in
				if !s { success = false }
				group.leave()
			}
		}
		group.wait()
		if !success { exit(1) }
	}

    static func failUpdate(_ message: String?) {
        printErrorMesage(message)
        log("[!Please provide one of the following options for 'update'!]")
		printOption(name: "all", description: "Update all items")
		log()
		
		log("[!Instead of 'all' you can combine the following!]")
		printOption(name: "repos", description: "Update repository list")
		printOption(name: "prs", description: "Update PRs")
		printOption(name: "issues", description: "Update issues")
		printOption(name: "comments", description: "Fetch comments PRs/Issues")
		printOption(name: "reactions", description: "Fetch reactions for items/comments")
        log()
        log("[!Options for notifications:!]")
        printOption(name: "-n", description: "List new comments and reviews on items")
        log()
    }

	private static func updateCheck(alwaysCheck: Bool, completion: @escaping (String?, Bool)->Void) {
		DispatchQueue.global(qos: .background).async {
			var newVersion: String?
			var success = false
			if alwaysCheck || config.lastUpdateCheckDate.timeIntervalSinceNow < -3600 {
				let versionURL = URL(string: "https://api.github.com/repos/ptsochantaris/trailer-cli/releases/latest")!
				if
					let data = try? Data(contentsOf: versionURL),
					let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [AnyHashable:Any],
					let tagName = json["tag_name"] as? String {

					success = true
					if config.isNewer(tagName) {
						newVersion = tagName
					}
				}
			}
			config.lastUpdateCheckDate = Date()
			completion(newVersion, success)
		}
	}

	static func checkForUpdatesSynchronously(reportError: Bool, alwaysCheck: Bool) {

		let g = DispatchGroup()
		g.enter()
		var n: String?
		var s = false
		updateCheck(alwaysCheck: alwaysCheck) { newVersion, success in
			n = newVersion
			s = success
			g.leave()
		}
		g.wait()
		if let n = n {
			log("[![G*New Trailer version \(n) is available*]!]")
		} else if !s {
			log("[R*(Latest version check failed)*]")
		}
	}

    static func processUpdateDirective(_ list: [String]) {
        guard list.count > 1 else {
			failUpdate("Need at least one update type. If in doubt, use 'all'.")
            return
        }

		var updateTypes = [UpdateType]()
		for param in list.dropFirst() {
			switch param {
			case "all": updateTypes.append(.all)
			case "repos": updateTypes.append(.repos)
			case "prs": updateTypes.append(.prs)
			case "issues": updateTypes.append(.issues)
			case "comments": updateTypes.append(.comments)
			case "reactions": updateTypes.append(.reactions)

			case "help":
				log()
				failUpdate(nil)
				return

			default:
				failUpdate("Unknown argmument: \(param)")
				return
			}
		}
		if updateTypes.count > 0 {
			update(updateTypes)
		} else {
			log()
			failUpdate("Need at least one update type. If in doubt, use 'all'.")
		}
    }

	private static func update(_ typesToSync: [UpdateType]) {

		var latestVersion: String?
		updateCheck(alwaysCheck: false) { newVersion, success in
			latestVersion = newVersion
		}

		DB.load()
		if let d = config.latestSyncDate {
			log(agoFormat(prefix: "[!Last update was ", since: d) + "!]")
		}
		log("Starting update...")
		config.totalQueryCosts = 0

		let userWantsAll = typesToSync.contains(.all)
		let userWantsRepos = userWantsAll || typesToSync.contains(.repos)
		let userWantsPrs = userWantsAll || typesToSync.contains(.prs)
		let userWantsIssues = userWantsAll || typesToSync.contains(.issues)
		let userWantsComments = userWantsAll || typesToSync.contains(.comments)
		let userWantsReactions = userWantsAll || typesToSync.contains(.reactions)

		///////////////////////////////////////////////////////////////////////////////////////////////////////////

		if userWantsRepos {
			let repositoryListQuery = Query(name: "Repos", rootElement:
				Group(name: "viewer", fields: [
					User.fragment,
					Group(name: "organizations", fields: [Org.fragmentWithRepos], usePaging: true),
					Group(name: "repositories", fields: [Repo.fragment], usePaging: true),
					Group(name: "watching", fields: [Repo.fragment], usePaging: true)
					]))
			successOrAbort(repositoryListQuery)
		} else {
			log(level: .info, "[*Repos*] (Skipped)")
			Org.assumeSynced()
			Repo.assumeSynced()
		}

		///////////////////////////////////////////////////////////////////////////////////////////////////////////

		var prIdList = [String: String]()
		if userWantsPrs {
			for p in PullRequest.allItems.values {
				if let r = p.repo, r.shouldSyncPrs {
					prIdList[p.id] = r.id
				}
			}
		}

		var issueIdList = [String: String]()
		if userWantsIssues {
			for i in Issue.allItems.values {
				if let r = i.repo, r.shouldSyncIssues {
					issueIdList[i.id] = r.id
				}
			}
		}

		if userWantsPrs || userWantsIssues {

			let itemIdParser = { (node: [AnyHashable : Any]) in

				guard let repoId = node["id"] as? String else {
					return
				}

				var syncPrs = true
				var syncIssues = true
				if let repo = Repo.allItems[repoId] {

					if repo.syncState == .none {
						return
					}

					switch repo.visibility {
					case .hidden:
						return
					case .onlyIssues:
						syncPrs = false
					case .onlyPrs:
						syncIssues = false
					case .visible:
						break
					}
				}

				if syncPrs, let section = node["pullRequests"] as? [AnyHashable : Any] {

					if let itemList = section["edges"] as? [[AnyHashable : Any]] {
						for p in itemList {
							let node = p["node"] as! [AnyHashable : Any]
							if let id = node["id"] as? String {
								prIdList[id] = repoId
								log(level: .debug, indent: 1, "Registered PR ID: \(id)")
							}
						}

					} else if let itemList = section["nodes"] as? [[AnyHashable : Any]] {
						for p in itemList {
							if let id = p["id"] as? String {
								prIdList[id] = repoId
								log(level: .debug, indent: 1, "Registered PR ID: \(id)")
							}
						}
					}
				}

				if syncIssues, let section = node["issues"] as? [AnyHashable : Any] {

					if let itemList = section["edges"] as? [[AnyHashable : Any]] {
						for p in itemList {
							let node = p["node"] as! [AnyHashable : Any]
							if let id = node["id"] as? String {
								issueIdList[id] = repoId
								log(level: .debug, indent: 1, "Registered Issue ID: \(id)")
							}
						}

					} else if let itemList = section["nodes"] as? [[AnyHashable : Any]] {
						for p in itemList {
							if let id = p["id"] as? String {
								issueIdList[id] = repoId
								log(level: .debug, indent: 1, "Registered Issue ID: \(id)")
							}
						}
					}
				}
			}

			let repoIds = Repo.allItems.values.flatMap { return $0.visibility == .hidden ? nil : $0.id }
			let fields =
				(userWantsPrs && userWantsIssues) ? [Repo.prAndIssueIdsFragment] :
					userWantsPrs ? [Repo.prIdsFragment] :
					userWantsIssues ? [Repo.issueIdsFragment] :
					[]
			let itemQueries = Query.batching("Item IDs", fields: fields, idList: repoIds, perNodeBlock: itemIdParser)
			successOrAbort(itemQueries)
		}

		if !userWantsPrs {
			log(level: .info, "[*PRs*] (Skipped)")
			PullRequest.assumeSynced()
			Issue.assumeSynced()
			Milestone.assumeSynced()
			Status.assumeSynced()
			Review.assumeSynced()
			ReviewRequest.assumeSynced()
			Label.assumeSynced()
			Reaction.assumeSynced()
			User.assumeSynced()
		}

		if !userWantsIssues {
			log(level: .info, "[*Issues*] (Skipped)")
			Issue.assumeSynced()
			Milestone.assumeSynced()
			Label.assumeSynced()
			Reaction.assumeSynced()
			User.assumeSynced()
		}

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////

		if prIdList.count > 0 {
			let fragment = userWantsComments ? PullRequest.fragmentWithComments : PullRequest.fragment
			let prQueries = Query.batching("PRs", fields: [fragment], idList: Array(prIdList.keys))
			successOrAbort(prQueries)

			let prsMissingParents = PullRequest.allItems.values.filter { $0.repo == nil }
			for pr in prsMissingParents {
				let prId = pr.id
				log(level: .debug, indent: 1, "Detected missing parent for PR ID '\(prId)'")
				if let repoIdForPr = prIdList[prId], let repo = Repo.allItems[repoIdForPr] {
					log(level: .debug, indent: 1, "Determined parent should be Repo ID '\(repoIdForPr)'")
					if let parent = Parent(item: repo, field: "pullRequests") {
						var newPr = pr
						newPr.makeChild(of: parent, indent: 1)
						PullRequest.allItems[prId] = newPr
					}
				}
			}
		}

		if issueIdList.count > 0 {
			let fragment = userWantsComments ? Issue.fragmentWithComments : Issue.fragment
			let issueQueries = Query.batching("Issues", fields: [fragment], idList: Array(issueIdList.keys))
			successOrAbort(issueQueries)

			let issuesMissingParents = Issue.allItems.values.filter { $0.repo == nil }
			for issue in issuesMissingParents {
				let issueId = issue.id
				log(level: .debug, indent: 1, "Detected missing parent for Issue ID '\(issueId)'")
				if let repoIdForIssue = issueIdList[issueId], let repo = Repo.allItems[repoIdForIssue] {
					log(level: .debug, indent: 1, "Determined parent should be Repo ID '\(repoIdForIssue)'")
					if let parent = Parent(item: repo, field: "issues") {
						var newIssue = issue
						newIssue.makeChild(of: parent, indent: 1)
						Issue.allItems[issueId] = newIssue
					}
				}
			}
		}

		///////////////////////////////////////////////////////////////////////////////////////////////////////////

		if userWantsComments {

			var itemIdsWithComments = [String]()

			if userWantsPrs {
				itemIdsWithComments += Review.allItems.values.flatMap { $0.syncState == .none || !$0.syncNeedsComments ? nil : $0.id }
			} else {
				itemIdsWithComments += Review.allItems.keys
				itemIdsWithComments += PullRequest.allItems.keys
			}

			if !userWantsIssues {
				itemIdsWithComments += Issue.allItems.keys
			}

			if itemIdsWithComments.count > 0 {
				successOrAbort(Query.batching("Comments", fields: [
					Review.commentsFragment,
					PullRequest.commentsFragment,
					Issue.commentsFragment,
					], idList: itemIdsWithComments))
			}

		} else {
			log(level: .info, "[*Comments*] (Skipped)")
			Comment.assumeSynced()
		}

		///////////////////////////////////////////////////////////////////////////////////////////////////////////

		if userWantsReactions {

			var itemIdsWithReactions = [String]()
			
			if userWantsComments {
				itemIdsWithReactions += Comment.allItems.values.flatMap { ($0.syncState == .none || !$0.syncNeedsReactions) ? nil : $0.id }
			} else {
				itemIdsWithReactions += Comment.allItems.keys
			}

			if userWantsPrs {
				itemIdsWithReactions += PullRequest.allItems.values.flatMap { ($0.syncState == .none || !$0.syncNeedsReactions) ? nil : $0.id }
			} else {
				itemIdsWithReactions += PullRequest.allItems.keys
			}

			if userWantsIssues {
				itemIdsWithReactions += Issue.allItems.values.flatMap { ($0.syncState == .none || !$0.syncNeedsReactions) ? nil : $0.id }
			} else {
				itemIdsWithReactions += Issue.allItems.keys
			}

			successOrAbort(Query.batching("Reactions", fields: [
				Comment.pullRequestReviewCommentReactionFragment,
				Comment.issueCommentReactionFragment,
				PullRequest.reactionsFragment,
				Issue.reactionsFragment
				], idList: itemIdsWithReactions))

		} else {
			log(level: .info, "[*Reactions*] (Skipped)")
			Reaction.assumeSynced()
		}

		///////////////////////////////////////////////////////////////////////////////////////////////////////////

		config.latestSyncDate = Date()

        let n: NotificationMode = (commandLineArgument(matching: "-n") != nil) ? .consoleCommentsAndReviews : .standard
		DB.save(purgeUntouchedItems: true, notificationMode: n)
        Notifications.processQueue()
		log("Update done.")
		if config.totalQueryCosts > 0 {
			log(level: .verbose, "Total update API cost: \(config.totalQueryCosts)")
		}
		if config.totalApiRemaining < Int.max {
			log(level: .verbose, "Remaining API limit: \(config.totalApiRemaining)")
		}
		if let l = latestVersion {
			log("[![G*New Trailer version \(l) is available*]!]")
		}
	}
}
