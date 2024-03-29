import Foundation

extension Actions {
    static func failOpen(_ message: String?) {
        printErrorMesage(message)
        printOptionHeader("Please provide one of the following options for 'open'")
        printOption(name: "item <number>", description: "Open any item with the specified number")
        printOption(name: "pr <number>", description: "Open an issue with the specified number")
        printOption(name: "issue <number>", description: "Open a PR with the specified number")
        printOption(name: "repo <name>", description: "Open the first repository matching 'name'")
        log()
        printFilterOptions()
    }

    static func processOpenDirective(_ list: [String]) async {
        if list.first == "help" {
            log()
            failOpen(nil)
        }

        guard list.count > 2 else {
            failOpen("Missing argument")
            return
        }

        let command = list[1]
        switch command {
        case "item":
            if let number = Int(list[2]) {
                await DB.load()
                if !openItemURL(number, includePrs: true, includeIssues: true) {
                    log("Item #\(number) not found")
                }
            } else {
                failOpen("Invalid number: \(list[2])")
            }
        case "pr":
            if let number = Int(list[2]) {
                await DB.load()
                if !openItemURL(number, includePrs: true, includeIssues: false) {
                    log("PR #\(number) not found")
                }
            } else {
                failOpen("Invalid number: \(list[2])")
            }
        case "issue":
            if let number = Int(list[2]) {
                await DB.load()
                if !openItemURL(number, includePrs: false, includeIssues: true) {
                    log("Issue #\(number) not found")
                }
            } else {
                failOpen("Invalid number: \(list[2])")
            }
        case "repo":
            await DB.load()
            let name = list[2]
            let repos = Repo.allItems.values.filter { $0.nameWithOwner.localizedCaseInsensitiveContains(name) }
            if repos.isEmpty {
                log("Repo '\(name)' not found")
            } else if repos.count > 1 {
                log("Multiple matches for '\(name)'. Did you mean...")
                for r in repos {
                    log("[![*> *]!]\(r.nameWithOwner)")
                }
            } else {
                open(url: repos.first!.url)
            }
        default:
            failOpen("Unknown argmument: \(command)")
        }
    }

    private static func openItemURL(_ number: Int, includePrs: Bool, includeIssues: Bool) -> Bool {
        if let items = findItems(number: number, includePrs: includePrs, includeIssues: includeIssues, warnIfMultiple: true) {
            if items.count == 1, let item = items.first {
                item.openUrl()
            }
            return items.count > 0
        }
        return false
    }
}
