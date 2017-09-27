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
		let invalidArguments = CommandLine.arguments.filter({ $0.hasPrefix("-") }).map { $0.lowercased() }.filter { arg in
            switch arg {
            case "-v", "-debug", "-server", "-token", "-r", "-o", "-t", "-a", "-l", "-h", "-b", "-c", "-comments", "-refresh", "-body", "-page-size",
                 "-mine", "-participated", "-mentioned", "-mergeable", "-conflict", "-red", "-green", "-e", "-before", "-within", "-n", "-purge",
                 "-mono", "-version", "-fresh", "-m", "-number", "-blocked", "-approved", "-unreviewed", "-active", "-inactive":
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

	static var terminalWidth: Int = {
		var w = winsize()
		_ = ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), UnsafeMutableRawPointer(&w))
		return w.ws_col == 0 ? 80 : Int(w.ws_col)
	}()

	static func printOptionHeader(_ text: String) {
		var line = ""

		for word in text.split(separator: " ") {
			if line.count + word.count + 1 > terminalWidth {
				log("[!\(line)!]")
				line = ""
			}
			line += (word + " ")
		}
		if !line.isEmpty {
			log("[!\(line)!]")
		}
	}

	static func printOption(name: String, description: String) {
		var firstLine = true
		var line = ""

		func dumpLine() {
			if firstLine {
				let firstIndent = max(0, 16 - name.count)
				log(indent: firstIndent, "[![*\(name)*]!] \(line)")
				firstLine = false
			} else {
				log(indent: 17, line)
			}
			line = ""
		}

		for word in description.split(separator: " ") {
			if 17 + line.count + word.count + 1 > terminalWidth {
				dumpLine()
			}
			line += (word + " ")
		}
		if !line.isEmpty {
			dumpLine()
		}
	}

	static func printErrorMesage(_ message: String?) {
		if let message = message {
			log()
			log("[![R*!! \(message)*]!]")
			log()
		}
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

	static func printFilterOptions(onlyRepos: Bool = false) {
		printOptionHeader("Filter options (can combine)")
		printOption(name :"-o <org>", description: "Filter for an org name")
		printOption(name :"-r <repo>", description: "Filter for a repo name")
        printOption(name :"-active", description: "Filter for repos configured for PRs or Issues")
        printOption(name :"-inactive", description: "Filter for repos configured as hidden")
		printOption(name :"-h", description: "Filter for repos/orgs with PRs or Issues")
		printOption(name :"-e", description: "Exclude repos/orgs with PRs or Issues")
		log()

		if onlyRepos {
			return
		}

		printOptionHeader("Filter options affecting PRs or Issues (can combine)")
		printOption(name :"-mine", description: "Items authored by me, or assigned to me")
		printOption(name :"-participated", description: "Items which I have commented on")
		printOption(name :"-mentioned", description: "Items mentioning me in their body or comments")
		printOption(name :"-before <days>", description: "Items updated before <days>")
		printOption(name :"-within <days>", description: "Items updated within <days>")
		printOption(name :"-number <num>", description: "Items with this number (Can also be a comma-separated list)")
		printOption(name :"-t <text>", description: "Filter for a specific title")
		printOption(name :"-b <text>", description: "Items containing 'text' in their body")
		printOption(name :"-c <text>", description: "Items containing 'text' in commens/reviews")
		printOption(name :"-a <author>", description: "Items by a specific author")
		printOption(name :"-l <label>", description: "Items with a specific label")
		printOption(name :"-m <milestone>", description: "Items with a specific milestone")
		log()
		printOptionHeader("Filter options affecting PRs (can combine)")
		printOption(name :"-mergeable", description: "Mergeable PRs")
		printOption(name :"-conflict", description: "Un-mergeable PRs")
		printOption(name :"-green", description: "PRs with only green statuses")
		printOption(name :"-red", description: "PRs containing red statuses")
		printOption(name :"-unreviewed", description: "PRs with pending reviews")
		printOption(name :"-blocked", description: "PRs where reviewers request changes")
		printOption(name :"-approved", description: "PRs where all reviewers approve")
		log()
	}

	static func reportAndExit(message: String?) -> Never {
		if let message = message {
			log()
			log("[![R*!! \(message)*]!]")
		}
		log()
		printOptionHeader("Usage: trailer [*<ACTION>*] <action options...> <advanced options...>")
		log()

		printOptionHeader("ACTION can be one of the following:")
		log()
		printOption(name: "update", description: "(Re)load local cache from GitHub. Specify 'help' for more info.")
		log()
		printOption(name: "list", description: "List or search for various items. Specify 'help' for more info.")
		log()
		printOption(name: "show", description: "Display details of specific items. Specify 'help' for more info.")
		log()
		printOption(name: "open", description: "Open the specific item in a web browser. If multiple items match, the first one opens. Specify 'help' for more info.")
		log()
		printOption(name: "config", description: "Visibility options for repositories. Specify 'help' for more info.")
		log()
		printOption(name: "stats", description: "List stats on stored data.")
		log()
		printOption(name: "reset", description: "Clear all stored data, including config/token.")
		log()

		printOptionHeader("Advanced options:")
		log()
		printOption(name: "-server <URL>", description: "Full URL to the API endpoint of the GitHub server you want to query. Defaults to 'https://api.github.com/graphql'.")
		log()
		printOption(name: "-token <token>", description: "Auth API token to use when accessing the default or selected server. The value given here is persisted and doesn't need to be repeated. '-token display' shows the stored token.")
		log()
		printOption(name: "-v / -debug", description: "Enable verbose output, -debug provides a debug trace.")
		log()
		printOption(name: "-page-size", description: "Minimum items fetched per API call (default: 100). If you get errors about queries failing, reduce this to a lower value. Must be between 10 and 100.")
		log()
		printOption(name: "-mono", description: "Generate monochrome text output.")
		log()

		exit(1)
	}
}
