//
//  Actions-Config.swift
//  trailer
//
//  Created by Paul Tsochantaris on 26/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

extension Actions {

	static func failConfig(_ message: String?) {
		printErrorMesage(message)
		log("[!Please provide one of the following options for 'config'!]")
		log()
		printOption(name: "view", description: "Shows current visibility of repos")
		printOption(name: "activate", description: "Allow trailer to fetch items from repos")
		printOption(name: "deactivate", description: "Block trailer from fetching items from repos")
		printOption(name: "only-prs", description: "Only fetch PRs from repos")
		printOption(name: "only-issues", description: "Only fetch Issues from repos")
		log()
		printFilterOptions(onlyRepos: true)
	}

	static private func setOption(visibility: RepoVisibility?) {
		DB.load()
		var changedCount = 0
		if let v = visibility {
			for r in reposToScan {
				if r.visibility != v {
					var newRepo = r
					newRepo.visibility = v
					Repo.allItems[r.id] = newRepo
					changedCount += 1
				}
			}
		}
		for r in reposToScan {
			r.printDetails()
		}
		if changedCount > 0 {
			DB.save(purgeUntouchedItems: false, notificationMode: .none)
		}
	}

	static func processConfigDirective(_ list: [String]) {

		guard list.count > 1 else {
			failShow("Missing argument")
			return
		}

		let command = list[1]

		switch command {
		case "help":
			log()
			failConfig(nil)
		case "activate":
			setOption(visibility: .visible)
		case "deactivate":
			setOption(visibility: .hidden)
		case "only-prs":
			setOption(visibility: .onlyPrs)
		case "only-issues":
			setOption(visibility: .onlyIssues)
		case "view":
			setOption(visibility: nil)
		default:
			failConfig("Unknown argmument: \(command)")
		}
	}
}
