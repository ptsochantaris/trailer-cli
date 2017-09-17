//
//  Actions-Show.swift
//  trailer
//
//  Created by Paul Tsochantaris on 26/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

extension Actions {

	static func failShow(_ message: String?) {
		printErrorMesage(message)
		printOptionHeader("Please provide one of the following options for 'show'")
		printOption(name: "item <number>", description: "Show any item with the specified number")
		printOption(name: "pr <number>", description: "Show an issue with the specified number")
		printOption(name: "issue <number>", description: "Show a PR with the specified number")
		log()
		printOptionHeader("Options (can combine)")
		printOption(name: "-body", description: "Show the body of the item")
		printOption(name: "-comments", description: "Show the comments on the item")
		log()
		printFilterOptions()
	}

	static func processShowDirective(_ list: [String]) {

		if list.first == "help" {
			log()
			failShow(nil)
		}

		guard list.count > 2 else {
			failShow("Missing argument")
			return
		}

		let command = list[1]
		switch command {
		case "item":
			if let number = Int(list[2]) {
				DB.load()
				if !showItem(number) {
					log("[R*Item #\(number) not found*]")
				}
			} else {
				failShow("Invalid number: \(list[2])")
			}

        case "pr":
			if let number = Int(list[2]) {
				DB.load()
				if !showPr(number) {
					log("[R*PR #\(number) not found*]")
				}
			} else {
				failShow("Invalid number: \(list[2])")
			}

        case "issue":
			if let number = Int(list[2]) {
				DB.load()
				if !showIssue(number) {
					log("[R*Issue #\(number) not found*]")
				}
			} else {
				failShow("Invalid number: \(list[2])")
			}

        default:
			failShow("Unknown argmument: \(command)")
		}
	}

	static private func showPr(_ number: Int) -> Bool {
		if let items = findItems(number: number, includePrs: true, includeIssues: false, warnIfMultiple: true) {
			if items.count == 1, let item = items.first {
				item.printDetails()
			}
			return items.count > 0
		}
		return false
	}

	static private func showIssue(_ number: Int) -> Bool {
		if let items = findItems(number: number, includePrs: false, includeIssues: true, warnIfMultiple: true) {
			if items.count == 1, let item = items.first {
				item.printDetails()
			}
			return items.count > 0
		}
		return false
	}
	
	static private func showItem(_ number: Int) -> Bool {
		if let items = findItems(number: number, includePrs: true, includeIssues: true, warnIfMultiple: true) {
			if items.count == 1, let item = items.first {
				item.printDetails()
			}
			return items.count > 0
		}
		return false
	}

}
