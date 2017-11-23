//
//  CommandLine.swift
//  trailer-cliPackageDescription
//
//  Created by Paul Tsochantaris on 17/09/2017.
//

import Foundation

private let _args = CommandLine.arguments.map { $0.lowercased() }

extension CommandLine {

	static func value(for argument: String) -> String? {
		guard let index = _args.index(of: argument) else { return nil }

		let valueIndex = index + 1
		if _args.count > valueIndex {
			let nextArg = _args[valueIndex]
			if nextArg.hasPrefix("-") {
				return ""
			}
			return nextArg
		}
		return ""
	}

	static func argument(exists argument: String) -> Bool {
		return _args.contains(argument)
	}

	static func argument(matching argument: String) -> String? {
		if let index = _args.index(of: argument) {
			return _args[index]
		}
		return nil
	}

	static func sequence(starting: String) -> [String]? {
		guard let index = _args.index(of: starting) else { return nil }

		var valueIndex = index + 1
		var value = [starting]
		while _args.count > valueIndex {
			let nextArg = _args[valueIndex]
			if nextArg.hasPrefix("-") {
				break
			}
			value.append(nextArg)
			valueIndex += 1
		}
		return value
	}
}

let listFieldsDefinition = ListFieldsDefinition()

struct ListFieldsDefinition {
	let type, number, title, repo, branch, author, created, updated, url, labels: Bool
	init() {
		let components = CommandLine.value(for: "-fields")?.split(separator: ",")
		type = components?.contains("type") ?? true
		number = components?.contains("number") ?? true
		author = components?.contains("author") ?? true
		title = components?.contains("title") ?? true
		repo = components?.contains("repo") ?? true
		branch = components?.contains("branch") ?? false
		created = components?.contains("created") ?? false
		updated = components?.contains("updated") ?? false
		labels = components?.contains("labels") ?? false
		url = components?.contains("url") ?? false
	}
}
