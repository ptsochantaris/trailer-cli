//
//  main.swift
//  V4APITest
//
//  Created by Paul Tsochantaris on 11/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation
#if os(Windows)
import WinSDK
#endif

private func setupConsole() {
    config.monochrome = CommandLine.argument(exists: "-mono")

    #if os(Windows)
    if !config.monochrome {
        let hOut = GetStdHandle(STD_OUTPUT_HANDLE)
        var dwMode: DWORD = 0
        
        guard hOut != INVALID_HANDLE_VALUE,
              GetConsoleMode(hOut, &dwMode)
        else {
            config.monochrome = true
            return
        }
        
        dwMode |= DWORD(ENABLE_VIRTUAL_TERMINAL_PROCESSING)
        guard SetConsoleMode(hOut, dwMode) else {
            config.monochrome = true
            return
        }
    }
    #endif
}

private func go() {

    setupConsole()
    
	if CommandLine.argument(exists: "-version") {
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

	if let p = CommandLine.value(for: "-page-size") {
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

	if CommandLine.argument(exists: "-debug") {
		globalLogLevel = .debug
		log("Will be verbose [*(debug)*]")
	} else if CommandLine.argument(exists: "-v") {
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
				log("Token for server [*\(config.server.absoluteString)*] is [*\(config.token)*]")
			}
			if actionDetected == nil {
				exit(0)
			}
		} else if t == "test" {
			if config.token.isEmpty {
				log("Token for server [*\(config.server.absoluteString)*] isn't set")
			} else {
				Actions.testToken()
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

	extendStackSizeIfNeeded()

	Actions.performAction(action, listSequence: actionSequence)
}

// With thanks to: https://stackoverflow.com/questions/2275550/change-stack-size-for-a-c-application-in-linux-during-compilation-with-gnu-com#2284691
private func extendStackSizeIfNeeded() {
    #if os(Windows)
        // is done with editbin /stack:24117248
    #else
        let kStackSize: rlim_t = 32 * 1024 * 1024
        var rl = rlimit()
        #if os(Linux)
            let s: Int32 = Int32(RLIMIT_STACK.rawValue)
        #else
            let s = RLIMIT_STACK
        #endif
        if getrlimit(s, &rl) == 0 {
            if rl.rlim_cur < kStackSize {
                rl.rlim_cur = kStackSize
                setrlimit(s, &rl)
            }
        }
    #endif
}

go()
