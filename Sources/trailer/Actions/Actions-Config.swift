import Foundation

extension Actions {
    static func failConfig(_ message: String?) {
        printErrorMesage(message)
        printOptionHeader("Please provide one of the following options for 'config'")
        log()
        printOption(name: "view", description: "Shows current visibility of repos")
        printOption(name: "activate", description: "Allow trailer to fetch items from repos")
        printOption(name: "deactivate", description: "Block trailer from fetching items from repos")
        printOption(name: "only-prs", description: "Only fetch PRs from repos")
        printOption(name: "only-issues", description: "Only fetch Issues from repos")
        log()
        printOptionHeader("New repos become visible by default. To change:")
        printOption(name: "-set-default", description: "Apply the above automatically to new repos")
        log()
        printFilterOptions(onlyRepos: true)
    }

    private static func setOption(visibility: RepoVisibility?) async {
        await DB.load()
        var changedCount = 0
        if let v = visibility {
            for r in reposToScan {
                if r.visibility != v {
                    var newRepo = r
                    newRepo.visibility = v
                    Repo.allItems[r.id] = newRepo
                    changedCount += 1
                }
            }
        }
        for r in reposToScan {
            r.printDetails()
        }
        if changedCount > 0 {
            await DB.save(purgeUntouchedItems: false, notificationMode: .none)
        }
    }

    private static func checkDefault(visibility: RepoVisibility) -> Bool {
        if CommandLine.argument(exists: "-set-default") {
            config.defaultRepoVisibility = visibility
            log("[!New repositories will now be auto-configured for visibility [*\(visibility.rawValue.uppercased())*]!]")
            log()
            return true
        }
        return false
    }

    private static func checkFiltering() -> Bool {
        if !RepoFilterArgs().filteringApplied {
            failConfig("Please supply filters that specify which repos to configure, such as -r")
            return false
        }
        return true
    }

    static func processConfigDirective(_ list: [String]) async {
        guard list.count > 1 else {
            failConfig("Missing argument")
            return
        }

        let command = list[1]

        switch command {
        case "help":
            log()
            failConfig(nil)
        case "activate":
            if !checkDefault(visibility: .visible), checkFiltering() {
                await setOption(visibility: .visible)
            }
        case "deactivate":
            if !checkDefault(visibility: .hidden), checkFiltering() {
                await setOption(visibility: .hidden)
            }
        case "only-prs":
            if !checkDefault(visibility: .onlyPrs), checkFiltering() {
                await setOption(visibility: .onlyPrs)
            }
        case "only-issues":
            if !checkDefault(visibility: .onlyIssues), checkFiltering() {
                await setOption(visibility: .onlyIssues)
            }
        case "view":
            await setOption(visibility: nil)
        default:
            failConfig("Unknown argmument: \(command)")
        }
    }
}
