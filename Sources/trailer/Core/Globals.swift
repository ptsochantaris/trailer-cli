//
//  Globals.swift
//  trailer
//
//  Created by Paul Tsochantaris on 18/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation
import Dispatch

let emptyURL = URL(string: "http://github.com")!

enum LogLevel: Int {
	case debug = 0, verbose = 1, info = 2
}

var globalLogLevel = LogLevel.info

func log(level: LogLevel = .info, indent: Int = 0, _ message: @autoclosure ()->String = "", unformatted: Bool = false) {
	if globalLogLevel.rawValue > level.rawValue { return }
    if indent > 0 {
        let spaces = String(repeating: " ", count: indent)
        print(spaces, terminator: "")
    }
    let m = message()
    if m.isEmpty {
        print()
    } else {
        if unformatted {
            print(m)
        } else {
            print(TTY.postProcess(m))
        }
    }
}

func commandLineValue(for argument: String) -> String? {
	let args = CommandLine.arguments
	if let index = args.index(where: { $0 == argument }) {
		let valueIndex = index + 1
		if args.count > valueIndex {
			let nextArg = args[valueIndex]
			if nextArg.hasPrefix("-") {
				return ""
			}
			return nextArg
		}
		return ""
	}
	return nil
}

func commandLineArgument(matching argument: String) -> String? {
	let args = CommandLine.arguments
	if let index = args.index(where: { $0 == argument }) {
		return args[index]
	}
	return nil
}

func commandLineSequence(starting: String) -> [String]? {
	let args = CommandLine.arguments
	if let index = args.index(where: { $0 == starting }) {
		var valueIndex = index + 1
		var value = [starting]
		while args.count > valueIndex {
			let nextArg = args[valueIndex]
			if nextArg.hasPrefix("-") {
				break
			}
			value.append(nextArg)
			valueIndex += 1
		}
		return value
	}
	return nil
}

func reportAndExit(message: String?) -> Never {
	if let message = message {
		log()
		log("[![R*!! \(message)*]!]")
	}
	log()
	log("[!Usage: trailer [-server <URL>] [-token <token>] [-v] [-V] [ACTION]!]")
	log()
	log("[![*\t-server <URL>*]!]\t\tFull URL to the API endpoint of the GitHub")
	log("\t\t\t\tserver you want to query. Defaults to")
	log("\t\t\t\t'https://api.github.com/graphql'")
	log()

	log("[![*\t-token <token>*]!]\t\tAuth API token to use when accessing the default")
	log("\t\t\t\tor selected server. The value given here is")
	log("\t\t\t\tpersisted and doesn't need to be repeated.")
	log("\t\t\t\t'-token display' shows the stored token.")
	log()

	log("[![*\t-v*]!]\t\t\tEnable verbose output, -V provides a debug trace")
	log()

	log("[![*\t-mono*]!]\t\t\tGenerate monochrome text output")
	log()

	log("[!ACTION can be one of the following - applies to the active server:!]")
	log()

	log("[![*\tupdate*]!]\t\t\t(Re)load local cache from GitHub.")
    log("\t\t\t\tSpecify 'help' for more info.")
	log()

	log("[![*\tlist*]!]\t\t\tList or search for various items.")
	log("\t\t\t\tSpecify 'help' for more info.")
	log()

	log("[![*\tshow*]!]\t\t\tDisplay details of specific items.")
	log("\t\t\t\tSpecify 'help' for more info.")
	log()

	log("[![*\topen*]!]\t\t\tOpen the specific item in a web browser.")
	log("\t\t\t\tIf multiple items match, the first one opens.")
	log("\t\t\t\tSpecify 'help' for more info.")
	log()

	log("[![*\tconfig*]!]\t\t\tVisibility options for repositories.")
	log("\t\t\t\tSpecify 'help' for more info.")
	log()

	log("[![*\tstats*]!]\t\t\tList stats on stored data.")
	log()

	log("[![*\treset*]!]\t\t\tClear all stored data, including config/token.")
	log()

	log()
	exit(1)
}

struct GHDateFormatter {
	#if os(OSX)
	private static var timeData = tm()
	private static var dateParserHolder = "                   +0000".cString(using: String.Encoding.ascii)!
	static func parseGH8601(_ iso8601: String?) -> Date? {

		guard let i = iso8601, i.count > 18 else { return nil }

		memcpy(&dateParserHolder, i, 19)
		strptime(dateParserHolder, "%FT%T%z", &timeData)

		let t = mktime(&timeData)
		return Date(timeIntervalSince1970: TimeInterval(t))
	}
	#elseif os(Linux)
	private static let formatter: DateFormatter = {
		let d = DateFormatter()
		d.timeZone = TimeZone(secondsFromGMT: 0)
		d.locale = Locale(identifier: "en_US_POSIX")
		d.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
		return d
	}()
	static func parseGH8601(_ iso8601: String?) -> Date? {
		guard let i = iso8601 else { return nil }
		return formatter.date(from: i)
	}
	#endif
}

#if os(OSX)
	private let agoFormatter: DateComponentsFormatter = {
		let f = DateComponentsFormatter()
		f.allowedUnits = [.year, .month, .weekOfMonth, .day, .hour, .minute, .second]
		f.unitsStyle = .full
		f.maximumUnitCount = 2
		return f
	}()
	func agoFormat(prefix: String, since: Date?) -> String {

		guard let since = since, since != .distantPast else {
			return "\(prefix)(unknown)"
		}

		let interval = -since.timeIntervalSinceNow
		if interval < 10.0 {
			if prefix.isEmpty {
				return "Just now"
			} else {
				return "\(prefix)just now"
			}
		} else {
			let duration = agoFormatter.string(from: since, to: Date()) ?? "unknown time"
			return "\(prefix)\(duration) ago"
		}
	}
#elseif os(Linux)
	private let agoFormatter: DateFormatter = {
		let f = DateFormatter()
		f.timeStyle = .full
		f.dateStyle = .full
		return f
	}()
	func agoFormat(prefix: String, since: Date?) -> String {

		guard let since = since, since != .distantPast else {
			return "\(prefix)(unknown)"
		}

		let interval = -since.timeIntervalSinceNow
		if interval < 60.0 {
			if prefix.isEmpty {
				return "Just now"
			} else {
				return "\(prefix)just now"
			}
		} else {
			let time = agoFormatter.string(from: since)
			return "\(prefix)\(time)"
		}
	}
#endif

