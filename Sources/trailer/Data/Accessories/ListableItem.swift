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
		return pullRequest?.id ?? issue?.id ?? ""
	}

	var title: String {
		return pullRequest?.title ?? issue?.title ?? ""
	}

	var createdAt: Date {
		return pullRequest?.createdAt ?? issue?.createdAt ?? .distantPast
	}

	var updatedAt: Date {
		return pullRequest?.updatedAt ?? issue?.updatedAt ?? .distantPast
	}

	var headRefName: String {
		return pullRequest?.headRefName ?? issue?.headRefName ?? ""
	}

	var number: Int {
		return pullRequest?.number ?? issue?.number ?? 0
	}

	var repo: Repo? {
		return pullRequest?.repo ?? issue?.repo
	}

	var author: User? {
		return pullRequest?.author ?? issue?.author
	}

	var type: Int {
		return pullRequest?.type ?? issue?.type ?? 0
	}

	func printSummaryLine() {
		switch self {
		case .issue(let i):
			i.printSummaryLine()
		case .pullRequest(let pr):
			pr.printSummaryLine()
		}
	}

    static func ==(lhs: ListableItem, rhs: ListableItem) -> Bool {
        switch lhs {
        case .pullRequest(let pr1):
            switch rhs {
            case .pullRequest(let pr2):
                return pr1 == pr2
            default: return false
            }
        case .issue(let issue1):
            switch rhs {
            case .issue(let issue2):
                return issue1 == issue2
            default: return false
            }
        }
    }

	var pullRequest: PullRequest? {
		switch self {
		case .pullRequest(let p):
			return p
		default:
			return nil
		}
	}

	var issue: Issue? {
		switch self {
		case .issue(let i):
			return i
		default:
			return nil
		}
	}

    func printDetails() {
        switch self {
        case .pullRequest(let i):
            i.printDetails()
        case .issue(let i):
            i.printDetails()
        }
    }

    func openUrl() {
        switch self {
        case .pullRequest(let i):
            open(url: i.url)
        case .issue(let i):
            open(url: i.url)
        }
    }
}
