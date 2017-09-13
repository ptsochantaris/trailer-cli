//
//  Actions-Scanning.swift
//  trailer-cliPackageDescription
//
//  Created by Paul Tsochantaris on 10/09/2017.
//

import Foundation

private let atCharacterSet: CharacterSet = {
	var c = CharacterSet()
	c.insert(charactersIn: "@")
	return c
}()

struct RepoFilterArgs {
	let searchForOrg = commandLineValue(for: "-o")
	let searchForRepo = commandLineValue(for: "-r")
	let hideEmpty = commandLineArgument(matching: "-h") != nil
	let onlyEmpty = commandLineArgument(matching: "-e") != nil

	var filteringApplied: Bool {
		return searchForOrg != nil
			|| searchForRepo != nil
			|| hideEmpty
			|| onlyEmpty
	}
}

struct ItemFilterArgs {
	let author = commandLineValue(for: "-a")?.trimmingCharacters(in: atCharacterSet)
	let title = commandLineValue(for: "-t")
	let body = commandLineValue(for: "-b")
	let comment = commandLineValue(for: "-c")
	let label = commandLineValue(for: "-l")
	let mine = commandLineArgument(matching: "-mine") != nil
	let participated = commandLineArgument(matching: "-participated") != nil
	let mentioned = commandLineArgument(matching: "-mentioned") != nil
	let mergeable = commandLineArgument(matching: "-mergeable") != nil
	let conflict = commandLineArgument(matching: "-conflict") != nil
	let red = commandLineArgument(matching: "-red") != nil
	let green = commandLineArgument(matching: "-green") != nil
	let olderThan = Int(commandLineValue(for: "-before") ?? "")
	let youngerThan = Int(commandLineValue(for: "-within") ?? "")

	var filteringApplied: Bool {
		return author != nil
			|| title != nil
			|| body != nil
			|| comment != nil
			|| label != nil
			|| mine
			|| participated
			|| mentioned
			|| mergeable
			|| conflict
			|| red
			|| green
			|| olderThan != nil
			|| youngerThan != nil
	}

	private let refDate: Date?

	init() {
		if let d = olderThan {
			refDate = Date(timeIntervalSinceNow: -24.0*3600.0*TimeInterval(d))
		} else if let d = youngerThan {
			refDate = Date(timeIntervalSinceNow: -24.0*3600.0*TimeInterval(d))
		} else {
			refDate = nil
		}
	}

	func dateValid(for date: Date) -> Bool {
		if olderThan != nil, let refDate = refDate {
			return date <= refDate
		} else if youngerThan != nil, let refDate = refDate {
			return date >= refDate
		} else {
			return true
		}
	}
}

extension Actions {

	static var reposToScan: [Repo] {

		let a = RepoFilterArgs()
		if !a.filteringApplied {
			return Array(Repo.allItems.values)
		}

		return Repo.allItems.values.filter { r in

			if let s = a.searchForOrg {
				if let on = r.org?.name {
					if !on.localizedCaseInsensitiveContains(s) {
						return false
					}
				} else {
					return false
				}
			}
			if let s = a.searchForRepo, !r.nameWithOwner.localizedCaseInsensitiveContains(s) {
				return false
			}
			if a.onlyEmpty && (r.pullRequests.count > 0 || r.issues.count > 0) {
				return false
			}
			if a.hideEmpty && (r.visibility == .hidden || (r.pullRequests.count == 0 && r.issues.count == 0)) {
				return false
			}

			return true

			}.sorted { $0.nameWithOwner < $1.nameWithOwner }
	}

	static func pullRequestsToScan(number: Int? = nil) -> [PullRequest] {
		let allItems = reposToScan.reduce([PullRequest]()) { result, repo -> [PullRequest] in
			return result + repo.pullRequests
		}

		let a = ItemFilterArgs()
		if !a.filteringApplied && number == nil {
			return allItems
		}

		return allItems.filter { p in

			if a.red || a.green {
				let s = p.statuses
				if a.red && !s.contains(where: { $0.state == .error || $0.state == .failure }) {
					return false
				}
				if a.green && s.contains(where: { $0.state != .success }) {
					return false
				}
			}

			if a.mergeable && p.mergeable != .mergeable {
				return false
			}

			if a.conflict && p.mergeable != .conflicting {
				return false
			}

			if let number = number, p.number != number {
				return false
			}

			if let a = a.author, !(p.author?.login.localizedCaseInsensitiveContains(a) ?? false) {
				return false
			}

			if let t = a.title, !p.title.localizedCaseInsensitiveContains(t) {
				return false
			}

			if let l = a.label, !p.labels.contains(where: { $0.id.localizedCaseInsensitiveContains(l) }) {
				return false
			}

			if !a.dateValid(for: p.updatedAt) {
				return false
			}

			if a.mine || a.participated || a.mentioned {
				var inSection = false
				if a.mine && (p.viewerDidAuthor || p.isAssignedToMe) {
					inSection = true
				}
				if a.participated && !inSection && p.commentedByMe {
					inSection = true
				}
				if a.mentioned && !inSection && p.mentionsMe {
					inSection = true
				}
				if !inSection {
					return false
				}
			}

			if let b = a.body {
				if !p.bodyText.localizedCaseInsensitiveContains(b) {
					return false
				}
			}

			if let c = a.comment {
				if !p.commentsOrReviewsInclude(text: c) {
					return false
				}
			}

			return true

		}.sorted { $0.number < $1.number }
	}

	static func issuesToScan(number: Int? = nil) -> [Issue] {
		let allItems = reposToScan.reduce([Issue]()) { result, repo -> [Issue] in
			return result + repo.issues
		}

		let a = ItemFilterArgs()
		if !a.filteringApplied && number == nil {
			return allItems
		}

		if a.mergeable || a.conflict || a.red || a.green {
			return []
		}

		return allItems.filter { i in

			if let number = number, i.number != number {
				return false
			}

			if let a = a.author, !(i.author?.login.localizedCaseInsensitiveContains(a) ?? false) {
				return false
			}

			if let t = a.title, !i.title.localizedCaseInsensitiveContains(t) {
				return false
			}

			if let l = a.label, !i.labels.contains(where: { $0.id.localizedCaseInsensitiveContains(l) }) {
				return false
			}

			if !a.dateValid(for: i.updatedAt) {
				return false
			}

			if a.mine || a.participated || a.mentioned {
				var inSection = false
				if a.mine && (i.viewerDidAuthor || i.isAssignedToMe) {
					inSection = true
				}
				if a.participated && !inSection && i.commentedByMe {
					inSection = true
				}
				if a.mentioned && !inSection && i.mentionsMe {
					inSection = true
				}
				if !inSection {
					return false
				}
			}

			if let b = a.body {
				if !i.bodyText.localizedCaseInsensitiveContains(b) {
					return false
				}
			}

			if let c = a.comment {
				if !i.commentsInclude(text: c) {
					return false
				}
			}

			return true

		}.sorted { $0.number < $1.number }
	}
}
