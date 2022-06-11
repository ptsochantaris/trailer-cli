//
//  ListableItem.swift
//  trailer
//
//  Created by Paul Tsochantaris on 28/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

enum ListableItem: Equatable, Sortable {
    case pullRequest(PullRequest)
    case issue(Issue)

    var id: String {
        pullRequest?.id ?? issue?.id ?? ""
    }

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

    static func == (lhs: ListableItem, rhs: ListableItem) -> Bool {
        switch lhs {
        case let .pullRequest(pr1):
            switch rhs {
            case let .pullRequest(pr2):
                return pr1 == pr2
            default: return false
            }
        case let .issue(issue1):
            switch rhs {
            case let .issue(issue2):
                return issue1 == issue2
            default: return false
            }
        }
    }

    var pullRequest: PullRequest? {
        switch self {
        case let .pullRequest(p):
            return p
        default:
            return nil
        }
    }

    var issue: Issue? {
        switch self {
        case let .issue(i):
            return i
        default:
            return nil
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
