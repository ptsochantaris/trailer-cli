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
		if let index = _args.index(where: { $0 == argument }) {
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
		return nil
	}

	static func argument(matching argument: String) -> String? {
		if let index = _args.index(where: { $0 == argument }) {
			return _args[index]
		}
		return nil
	}

	static func sequence(starting: String) -> [String]? {
		if let index = _args.index(where: { $0 == starting }) {
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
		return nil
	}
}
