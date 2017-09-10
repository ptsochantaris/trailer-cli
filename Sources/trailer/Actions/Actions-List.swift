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
		for p in pullRequestsToScan() {
			labels.append(contentsOf: p.labels)
		}
		for i in issuesToScan() {
			labels.append(contentsOf: i.labels)
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

	static private func listPrs() {
		for i in pullRequestsToScan() {
			i.printSummaryLine()
		}
	}

	static private func listIssues() {
		for i in issuesToScan() {
			i.printSummaryLine()
		}
	}

	static private func listItems() {
		for i in pullRequestsToScan() {
			i.printSummaryLine()
		}
		for i in issuesToScan() {
			i.printSummaryLine()
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
