import Foundation

extension Actions {
    static func failShow(_ message: String?) {
        printErrorMesage(message)
        printOptionHeader("Please provide one of the following options for 'show'")
        printOption(name: "item <number>", description: "Show any item with the specified number")
        printOption(name: "pr <number>", description: "Show a PR with the specified number")
        printOption(name: "issue <number>", description: "Show an issue with the specified number")
        log()
        printOptionHeader("Options (can combine)")
        printOption(name: "-body", description: "Show the body of the item")
        printOption(name: "-comments", description: "Show the comments on the item")
        printOption(name: "-refresh", description: "Update item (& comments, if requested) from remote")
        log()
        printFilterOptions()
    }

    static func processShowDirective(_ list: [String]) async throws {
        if list.first == "help" {
            log()
            failShow(nil)
        }

        guard list.count > 2 else {
            failShow("Missing argument")
            return
        }

        guard let number = Int(list[2]) else {
            failShow("Invalid number: \(list[2])")
            return
        }

        let command = list[1]
        switch command {
        case "item":
            await DB.load()
            if try await !showItem(number, includePrs: true, includeIssues: true) {
                log("[R*Item #\(number) not found*]")
            }

        case "pr":
            await DB.load()
            if try await !showItem(number, includePrs: true, includeIssues: false) {
                log("[R*PR #\(number) not found*]")
            }

        case "issue":
            await DB.load()
            if try await !showItem(number, includePrs: false, includeIssues: true) {
                log("[R*Issue #\(number) not found*]")
            }

        default:
            failShow("Unknown argmument: \(command)")
        }
    }

    private static func showItem(_ number: Int, includePrs: Bool, includeIssues: Bool) async throws -> Bool {
        if let items = findItems(number: number, includePrs: includePrs, includeIssues: includeIssues, warnIfMultiple: true) {
            if items.count == 1, var item = items.first {
                if CommandLine.argument(exists: "-refresh") {
                    item = try await Actions.singleItemUpdate(for: item)
                }
                item.printDetails()
            }
            return items.count > 0
        }
        return false
    }
}
