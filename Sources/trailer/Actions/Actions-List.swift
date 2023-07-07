import Foundation

extension Actions {
    static func failList(_ message: String?) {
        printErrorMesage(message)
        printOptionHeader("Please provide one of the following options for 'list'")
        printOption(name: "orgs", description: "List organisations")
        printOption(name: "repos", description: "List repositories")
        printOption(name: "prs", description: "List open PRs")
        printOption(name: "issues", description: "List open Issues")
        printOption(name: "items", description: "List open PRs and Issues")
        printOption(name: "labels", description: "List labels currently in use")
        printOption(name: "milestones", description: "List milestones currently set")

        log()
        printOptionHeader("For lists of PRs or Issues you can display specific fields, and/or sort by them")
        printOption(name: "-fields", description: "Comma-separated list: type, number, title, repo, branch, author, created, updated, url, labels")
        printOption(name: "-sort", description: "Comma-separated list: type, number, title, repo, branch, author, created, updated")

        log()
        printFilterOptions()
    }

    static func processListDirective(_ list: [String]) async {
        guard list.count > 1 else {
            failList("Missing argument")
            return
        }

        let command = list[1]
        switch command {
        case "repos":
            await DB.load()
            listRepos()
        case "prs":
            await DB.load()
            listPrs()
        case "issues":
            await DB.load()
            listIssues()
        case "items":
            await DB.load()
            listItems()
        case "orgs":
            await DB.load()
            listOrgs()
        case "labels":
            await DB.load()
            listLabels()
        case "milestones":
            await DB.load()
            listMilestones()
        case "help":
            log()
            failList(nil)
        default:
            failList("Unknown argmument: \(command)")
        }
    }

    private static func listLabels() {
        var uniquedIds = Set<String>()
        for p in pullRequestsToScan() {
            for id in p.labels.map(\.id) {
                uniquedIds.insert(id)
            }
        }
        for i in issuesToScan() {
            for id in i.labels.map(\.id) {
                uniquedIds.insert(id)
            }
        }
        for l in uniquedIds.sorted(by: { $0 < $1 }) {
            log("[![*> *]\(l)!]")
        }
    }

    private static func listMilestones() {
        let milestoneTitles = pullRequestsToScan().compactMap { $0.milestone?.title }
            + issuesToScan().compactMap { $0.milestone?.title }

        for l in milestoneTitles.sorted() {
            log("[![*> *]\(l)!]")
        }
    }

    private static func listRepos() {
        for r in reposToScan {
            r.printDetails()
        }
    }

    private static func listPrs() {
        for i in pullRequestsToScan().sortedByCriteria {
            i.printSummaryLine()
        }
    }

    private static func listIssues() {
        for i in issuesToScan().sortedByCriteria {
            i.printSummaryLine()
        }
    }

    private static func listItems() {
        let p = pullRequestsToScan().map { ListableItem.pullRequest($0) }
        let i = issuesToScan().map { ListableItem.issue($0) }
        for item in (p + i).sortedByCriteria {
            item.printSummaryLine()
        }
    }

    private static func listOrgRepos(_ o: Org?, hideEmpty: Bool, onlyEmpty: Bool) {
        let r: [Repo]
        let name: String
        if let o {
            r = o.repos
            name = o.name
        } else {
            r = Repo.allItems.values.filter { $0.org == nil }
            name = "(No org)"
            if r.isEmpty {
                return
            }
        }

        let totalRepos = r.count
        let totalPrs = r.reduce(0) { $0 + $1.pullRequests.count }
        let totalIssues = r.reduce(0) { $0 + $1.issues.count }
        if onlyEmpty, totalPrs + totalIssues > 0 {
            return
        }
        if hideEmpty, totalPrs + totalIssues == 0 {
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

    private static func listOrgs() {
        let searchForOrg = CommandLine.value(for: "-o")
        let hideEmpty = CommandLine.argument(exists: "-h")
        let onlyEmpty = CommandLine.argument(exists: "-e")
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
