//
//  main.swift
//  V4APITest
//
//  Created by Paul Tsochantaris on 11/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

private func go() {

	if CommandLine.argument(matching: "-mono") != nil {
		config.monochrome = true
	}

	if CommandLine.argument(matching: "-version") != nil {
		log("[!Version [*\(config.versionString)*]!]")
		Actions.checkForUpdatesSynchronously(reportError: true, alwaysCheck: true)
		log()
		exit(0)
	}

	if let s = URL(string: CommandLine.value(for: "-server") ?? "https://api.github.com/graphql"), s.host != nil {
		config.server = s
	} else {
		Actions.reportAndExit(message: "Provided server URL is invalid")
	}

	if let p = CommandLine.value(for: "-pageSize") {
		if let i = Int(p) {
			if i < 10 || i > 100 {
				Actions.reportAndExit(message: "Provided page size '\(p)' is invalid, must be from 10 to 100")
			} else {
				config.pageSize = i
			}
		} else {
			Actions.reportAndExit(message: "Provided page size '\(p)' isn't a number")
		}
	}

	if CommandLine.argument(matching: "-V") != nil {
		globalLogLevel = .debug
		log("Will be verbose [*(debug)*]")
	} else if CommandLine.argument(matching: "-v") != nil {
		globalLogLevel = .verbose
		log("Will be verbose")
	}

	let listSequence = CommandLine.sequence(starting: "list")
	let openSequence = CommandLine.sequence(starting: "open")
	let showSequence = CommandLine.sequence(starting: "show")
	let updateSequence = CommandLine.sequence(starting: "update")
	let configSequence = CommandLine.sequence(starting: "config")
	let actionSequence = listSequence ?? openSequence ?? showSequence ?? updateSequence ?? configSequence

	let actionString = CommandLine.argument(matching: "reset")
		?? actionSequence?.first
		?? CommandLine.argument(matching: "stats")
		?? ""

	let actionDetected = Action(rawValue: actionString)

	if let t = CommandLine.value(for: "-token") {
		if t.isEmpty {
			Actions.reportAndExit(message: "Parameter -token requires a token value")
		} else if t == "display" {
			if config.token.isEmpty {
				log("Token for server [*\(config.server.absoluteString)*] isn't set")
			} else {
				log("Token for server [*\(config.server.absoluteString)*] is '\(config.token)'")
			}
			if actionDetected == nil {
				exit(0)
			}
		} else {
			config.token = t
			log("Token for server [*\(config.server.absoluteString)*] has been set to [*\(t)*]")
			if actionDetected == nil {
				exit(0)
			}
		}
	}

	if actionDetected == .update {
		if config.token.isEmpty {
			Actions.reportAndExit(message: "You do not have an access token configured for this server, use the '-token' option to add one.")
		}
	}

	guard let action = actionDetected else {
		Actions.reportAndExit(message: nil)
	}

	Actions.performAction(action, listSequence: actionSequence)
}

go()
