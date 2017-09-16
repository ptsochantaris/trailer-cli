//
//  actions.swift
//  V4APITest
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

enum Action: String {
	case update
	case reset
	case list
	case show
	case open
	case config
	case stats
}

struct Actions {

    private static func checkArguments() -> [String]? {
        // Very rough sanity check to catch typos, should be more fine-grained per action
        let invalidArguments = CommandLine.arguments.filter({ $0.hasPrefix("-") }).filter { arg in
            switch arg {
            case "-v", "-V", "-server", "-token", "-r", "-o", "-t", "-a", "-l", "-h", "-b", "-c", "-comments", "-body", "-pageSize", "-mine", "-participated", "-mentioned",
                 "-mergeable", "-conflict", "-red", "-green", "-e", "-before", "-within", "-n", "-purge", "-mono", "-version", "-fresh", "-m", "-number", "-blocked", "-approved", "-unreviewed":
                return false
            default:
                return true
            }
        }
        if invalidArguments.count > 0 {
            return invalidArguments
        } else {
            return nil
        }
    }

	static func performAction(_ action: Action, listSequence: [String]?) {
		switch action {
		case .update:
            if let i = checkArguments() {
                Actions.failUpdate("Unknown argument(s): \(i.joined(separator: ", "))")
                exit(1)
            }
			if let listSequence = listSequence {
				Actions.processUpdateDirective(listSequence)
			}

		case .reset:
			log("[!Will delete token and data for '\(config.server)' in 5 seconds[R*")
			log("[&Press CTRL-C to abort*]&]!]")
			log()
			Thread.sleep(until: Date(timeIntervalSinceNow: 5))
			try! FileManager.default.removeItem(at: config.saveLocation)
			log("All data for [*\(config.server)*] has been removed")

		case .list:
            if let i = checkArguments() {
                Actions.failList("Unknown argument(s): \(i.joined(separator: ", "))")
                exit(1)
            }
			if let listSequence = listSequence {
				Actions.processListDirective(listSequence)
			}

		case .open:
            if let i = checkArguments() {
                Actions.failOpen("Unknown argument(s): \(i.joined(separator: ", "))")
                exit(1)
            }
			if let listSequence = listSequence {
				Actions.processOpenDirective(listSequence)
			}

		case .show:
            if let i = checkArguments() {
                Actions.failShow("Unknown argument(s): \(i.joined(separator: ", "))")
                exit(1)
            }
			if let listSequence = listSequence {
				Actions.processShowDirective(listSequence)
			}

		case .config:
            if let i = checkArguments() {
                Actions.failConfig("Unknown argument(s): \(i.joined(separator: ", "))")
                exit(1)
            }
			if let listSequence = listSequence {
				Actions.processConfigDirective(listSequence)
			}

		case .stats:
			DB.printStats()
		}
	}

	static func printOption(name: String, description: String) {
        let count = max(0, 16 - name.count)
        let spaces = String(repeating: " ", count: count)
		log("\t[![*\(name)*]!]\(spaces)\(description)")
	}

	static func printErrorMesage(_ message: String?) {
		if let message = message {
			log()
			log("[![R*!! \(message)*]!]")
			log()
		}
	}

	static func printFilterOptions(onlyRepos: Bool = false) {
		log("[!Filter options (can combine)!]")
		printOption(name :"-o <org>", description: "Filter for an org name")
		printOption(name :"-r <repo>", description: "Filter for a repo name")
		printOption(name :"-h", description: "Exclude repos/orgs without PRs or Issues")
		printOption(name :"-e", description: "Exclude repos/orgs with PRs or Issues")
		log()

		if onlyRepos {
			return
		}

		log("[!Filter options affecting PRs or Issues (can combine)!]")
		printOption(name :"-mine", description: "Filter for items authored by me, or assigned to me")
		printOption(name :"-participated", description: "Filter for items which I have commented on")
		printOption(name :"-mentioned", description: "Filter for items mentioning me in their body or comments")
        printOption(name :"-before <days>", description: "Filter for items updated before <days>")
        printOption(name :"-within <days>", description: "Filter for items updated within <days>")
		printOption(name :"-number <num>", description: "Filter for items with this number")
		printOption(name :"", description: "(Can also be a comma-separated list)")
		printOption(name :"-t <text>", description: "Filter for a specific title")
		printOption(name :"-b <text>", description: "Filter for items containing 'text' in their body")
		printOption(name :"-c <text>", description: "Filter for items containing 'text' in commens/reviews")
		printOption(name :"-a <author>", description: "Filter for a specific author")
		printOption(name :"-l <label>", description: "Filter for a specific label")
		printOption(name :"-m <milestone>", description: "Filter for a specific milestone")
		log()
		log("[!Filter options affecting PRs (can combine)!]")
		printOption(name :"-mergeable", description: "Filter for mergeable PRs")
		printOption(name :"-conflict", description: "Filter for un-mergeable PRs")
		printOption(name :"-green", description: "Filter for PRs with only green statuses")
		printOption(name :"-red", description: "Filter for PRs containing red statuses")
		log()
	}

	static func findItems(number: Int, includePrs: Bool, includeIssues: Bool, warnIfMultiple: Bool) -> [ListableItem]? {
		var items = [ListableItem]()
		if includePrs {
			let prs = Actions.pullRequestsToScan(number: number).map { ListableItem.pullRequest($0) }
			items.append(contentsOf: prs)
		}
		if includeIssues {
			let issues = Actions.issuesToScan(number: number).map { ListableItem.issue($0) }
			items.append(contentsOf: issues)
		}
		if warnIfMultiple && items.count > 1 {
			if includePrs && !includeIssues {
				log("Multiple repositories with issue [*#\(number)*]. Use -r to select a repository. Did you mean...")
			} else if includeIssues && !includePrs {
				log("Multiple repositories with a PR [*#\(number)*]. Use -r to select a repository. Did you mean...")
			} else {
				log("Multiple repositories with an item [*#\(number)*]. Use -r to select a repository. Did you mean...")
			}
			for i in items {
				switch i {
				case .pullRequest(let i):
					i.printSummaryLine()
				case .issue(let i):
					i.printSummaryLine()
				}
			}
		}
		return items
	}
}
