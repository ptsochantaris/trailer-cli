//
//  Actions-List.swift
//  trailer
//
//  Created by Paul Tsochantaris on 26/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

extension Actions {

	static func failList(_ message: String?) {
		printErrorMesage(message)
		log("[!Please provide one of the following options for 'list'!]")
		printOption(name: "orgs", description: "List organisations")
		printOption(name: "repos", description: "List repositories")
		printOption(name: "prs", description: "List open PRs")
		printOption(name: "issues", description: "List open Issues")
		printOption(name: "items", description: "List open PRs and Issues")
		printOption(name: "labels", description: "List labels currently in use")
		log()
		printFilterOptions()
	}

	static func processListDirective(_ list: [String]) {
		guard list.count > 1 else {
			failList("Missing argument")
			return
		}
		let command = list[1]
		switch command {
		case "repos":
			DB.load()
			listRepos()
		case "prs":
			DB.load()
			listPrs()
		case "issues":
			DB.load()
			listIssues()
		case "items":
			DB.load()
			listItems()
		case "orgs":
			DB.load()
			listOrgs()
		case "labels":
			DB.load()
			listLabels()
		case "help":
            log()
			failList(nil)
		default:
			failList("Unknown argmument: \(command)")
		}
	}

	static private func listLabels() {

		var labels = [Label]()
		for r in reposToScan {
			for p in pullRequestsToScan(in: r) {
				labels.append(contentsOf: p.labels)
			}
			for i in issuesToScan(in: r) {
				labels.append(contentsOf: i.labels)
			}
		}
		let ids = Array(Set(labels.map({ $0.id }))).sorted(by: { $0 < $1 })
		for l in ids {
            log("[![*> *]\(l)!]")
		}
	}

	static private func listRepos() {
		for r in reposToScan {
			r.printDetails()
		}
	}

	static var reposToScan: [Repo] {
		let searchForOrg = commandLineValue(for: "-o")
		let searchForRepo = commandLineValue(for: "-r")
		let hideEmpty = commandLineArgument(matching: "-h") != nil
		let onlyEmpty = commandLineArgument(matching: "-e") != nil
		return parallelFilter(Array(Repo.allItems.values)) { r in

			if let s = searchForOrg {
				if let on = r.org?.name {
					if !on.localizedCaseInsensitiveContains(s) {
						return false
					}
				} else {
					return false
				}
			}
			if let s = searchForRepo, !r.nameWithOwner.localizedCaseInsensitiveContains(s) {
				return false
			}
			if onlyEmpty && (r.pullRequests.count > 0 || r.issues.count > 0) {
				return false
			}
			if hideEmpty && (r.visibility == .hidden || (r.pullRequests.count == 0 && r.issues.count == 0)) {
				return false
			}

			return true

		}.sorted { $0.nameWithOwner < $1.nameWithOwner }
	}

	static func pullRequestsToScan(in repo: Repo, number: Int? = nil) -> [PullRequest] {
		let a = Args()
		return parallelFilter(repo.pullRequests) { p in

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
            return true

        }.sorted { $0.number < $1.number }
	}

	static private let atCharacterSet: CharacterSet = {
		var c = CharacterSet()
		c.insert(charactersIn: "@")
		return c
	}()

	private struct Args {
		let author = commandLineValue(for: "-a")?.trimmingCharacters(in: atCharacterSet)
		let title = commandLineValue(for: "-t")
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

	static func issuesToScan(in repo: Repo, number: Int? = nil) -> [Issue] {
		let a = Args()
		if a.mergeable || a.conflict || a.red || a.green {
			return []
		}

		return parallelFilter(repo.issues) { i in

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
            return true

        }.sorted { $0.number < $1.number }
	}

	static private func listPrs() {
		for r in reposToScan {
			for i in pullRequestsToScan(in: r) {
				i.printSummaryLine()
			}
		}
	}

	static private func listIssues() {
		for r in reposToScan {
			for i in issuesToScan(in: r) {
				i.printSummaryLine()
			}
		}
	}

	static private func listItems() {
		for r in reposToScan {
			for i in pullRequestsToScan(in: r) {
				i.printSummaryLine()
			}
			for i in issuesToScan(in: r) {
				i.printSummaryLine()
			}
		}
	}

	static private func listOrgRepos(_ o: Org?, hideEmpty: Bool, onlyEmpty: Bool) {

		let r: [Repo]
		let name: String
		if let o = o {
			r = o.repos
			name = o.name
		} else {
			r = Repo.allItems.values.filter({ $0.org == nil })
			name = "(No org)"
			if r.count == 0 {
				return
			}
		}

		let totalRepos = r.count
		let totalPrs = r.reduce(0, { $0 + $1.pullRequests.count })
		let totalIssues = r.reduce(0, { $0 + $1.issues.count })
		if onlyEmpty && (totalPrs+totalIssues > 0) {
			return
		}
		if hideEmpty && (totalPrs+totalIssues == 0) {
			return
		}
        var line = "[![*> *]\(name)!] ([![*\(totalRepos)*]!] Repositories"
		if totalPrs > 0 {
            line += ", [![*\(totalPrs)*]!] PRs"
		}
		if totalIssues > 0 {
            line += ", [![*\(totalIssues)*]!] Issues"
		}
        line += ")"
        log(line)
	}

	static private func listOrgs() {
		let searchForOrg = commandLineValue(for: "-o")
		let hideEmpty = commandLineArgument(matching: "-h") != nil
		let onlyEmpty = commandLineArgument(matching: "-e") != nil
		for o in Org.allItems.values.sorted(by: { $0.name < $1.name }) {
			if let s = searchForOrg, !o.name.localizedCaseInsensitiveContains(s) {
				continue
			}
			listOrgRepos(o, hideEmpty: hideEmpty, onlyEmpty: onlyEmpty)
		}
		if searchForOrg == nil {
			listOrgRepos(nil, hideEmpty: hideEmpty, onlyEmpty: onlyEmpty)
		}
	}
}
