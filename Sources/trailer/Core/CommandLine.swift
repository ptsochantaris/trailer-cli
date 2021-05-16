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
		guard let index = _args.firstIndex(of: argument) else { return nil }

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
		if let index = _args.firstIndex(of: argument) {
			return _args[index]
		}
		return nil
	}

	static func sequence(starting: String) -> [String]? {
		guard let index = _args.firstIndex(of: starting) else { return nil }

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

private struct ListSortDefinition {
	enum Criterion: String {
		case number, title, repo, branch, author, created, updated, type
	}

	let sortFunctions: [(Sortable, Sortable) -> Bool?]

	init() {
		let criteria: [Criterion]

		let components = CommandLine.value(for: "-sort")?.split(separator: ",")
		let s = components?.compactMap { Criterion(rawValue: String($0)) }
		if let s = s, s.hasItems {
			criteria = s
		} else {
			criteria = [.number, .title, .created]
		}

		sortFunctions = criteria.map { sortCriterion -> ((Sortable, Sortable) -> Bool?) in
			switch sortCriterion {
			case .number:
				return {
					let n1 = $0.number
					let n2 = $1.number
					if n1 < n2 { return true }
					if n1 > n2 { return false }
					return nil
				}
			case .author:
				return {
					let a1 = $0.author?.login ?? ""
					let a2 = $1.author?.login ?? ""
					let res = a1.localizedCaseInsensitiveCompare(a2)
					switch res {
					case .orderedAscending: return true
					case .orderedDescending: return false
					case .orderedSame: return nil
					}
				}
			case .branch:
				return {
					let a1 = $0.headRefName
					let a2 = $1.headRefName
					let res = a1.localizedCaseInsensitiveCompare(a2)
					switch res {
					case .orderedAscending: return true
					case .orderedDescending: return false
					case .orderedSame: return nil
					}
				}
			case .created:
				return {
					let d1 = $0.createdAt
					let d2 = $1.createdAt
					if d1 < d2 { return true }
					if d1 > d2 { return false }
					return nil
				}
			case .updated:
				return {
					let u1 = $0.updatedAt
					let u2 = $1.updatedAt
					if u1 < u2 { return true }
					if u1 > u2 { return false }
					return nil
				}
			case .repo:
				return {
					let a1 = $0.repo?.nameWithOwner ?? ""
					let a2 = $1.repo?.nameWithOwner ?? ""
					let res = a1.localizedCaseInsensitiveCompare(a2)
					switch res {
					case .orderedAscending: return true
					case .orderedDescending: return false
					case .orderedSame: return nil
					}
				}
			case .title:
				return {
					let a1 = $0.title
					let a2 = $1.title
					let res = a1.localizedCaseInsensitiveCompare(a2)
					switch res {
					case .orderedAscending: return true
					case .orderedDescending: return false
					case .orderedSame: return nil
					}
				}
			case .type:
				return {
					let t1 = $0.type
					let t2 = $1.type
					if t1 < t2 { return true }
					if t1 > t2 { return false }
					return nil
				}
			}
		}
	}
}

private let listSortDefinition = ListSortDefinition()

extension Array where Element: Sortable {
	var sortedByCriteria: [Element] {
		return sorted {
			for sf in listSortDefinition.sortFunctions {
				if let result = sf($0, $1) {
					return result
				}
			}
			return false
		}
	}
}
