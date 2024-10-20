import Foundation

@MainActor
enum ListableItem: Equatable, Sortable {
    case pullRequest(PullRequest)
    case issue(Issue)

    var title: String {
        pullRequest?.title ?? issue?.title ?? ""
    }

    var createdAt: Date {
        pullRequest?.createdAt ?? issue?.createdAt ?? .distantPast
    }

    var updatedAt: Date {
        pullRequest?.updatedAt ?? issue?.updatedAt ?? .distantPast
    }

    var headRefName: String {
        pullRequest?.headRefName ?? issue?.headRefName ?? ""
    }

    var number: Int {
        pullRequest?.number ?? issue?.number ?? 0
    }

    var repo: Repo? {
        pullRequest?.repo ?? issue?.repo
    }

    var author: User? {
        pullRequest?.author ?? issue?.author
    }

    var type: Int {
        pullRequest?.type ?? issue?.type ?? 0
    }

    func printSummaryLine() {
        switch self {
        case let .issue(i):
            i.printSummaryLine()
        case let .pullRequest(pr):
            pr.printSummaryLine()
        }
    }

    nonisolated static func == (lhs: ListableItem, rhs: ListableItem) -> Bool {
        switch lhs {
        case let .pullRequest(pr1):
            switch rhs {
            case let .pullRequest(pr2):
                pr1 == pr2
            default: false
            }
        case let .issue(issue1):
            switch rhs {
            case let .issue(issue2):
                issue1 == issue2
            default: false
            }
        }
    }

    var pullRequest: PullRequest? {
        switch self {
        case let .pullRequest(p):
            p
        default:
            nil
        }
    }

    var issue: Issue? {
        switch self {
        case let .issue(i):
            i
        default:
            nil
        }
    }

    func printDetails() {
        switch self {
        case let .pullRequest(i):
            i.printDetails()
        case let .issue(i):
            i.printDetails()
        }
    }

    func openUrl() {
        switch self {
        case let .pullRequest(i):
            open(url: i.url)
        case let .issue(i):
            open(url: i.url)
        }
    }
}
