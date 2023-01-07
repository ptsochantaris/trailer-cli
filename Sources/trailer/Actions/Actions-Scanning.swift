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
    let searchForOrg = CommandLine.value(for: "-o")
    let searchForRepo = CommandLine.value(for: "-r")
    let hideEmpty = CommandLine.argument(exists: "-h")
    let onlyEmpty = CommandLine.argument(exists: "-e")
    let onlyActive = CommandLine.argument(exists: "-active")
    let onlyInactive = CommandLine.argument(exists: "-inactive")

    var filteringApplied: Bool {
        searchForOrg != nil
            || searchForRepo != nil
            || onlyActive
            || onlyInactive
            || hideEmpty
            || onlyEmpty
    }
}

struct ItemFilterArgs {
    let author = CommandLine.value(for: "-a")?.trimmingCharacters(in: atCharacterSet)
    let title = CommandLine.value(for: "-t")
    let body = CommandLine.value(for: "-b")
    let comment = CommandLine.value(for: "-c")
    let label = CommandLine.value(for: "-l")
    let milestone = CommandLine.value(for: "-m")

    let mine = CommandLine.argument(exists: "-mine")
    let participated = CommandLine.argument(exists: "-participated")
    let mentioned = CommandLine.argument(exists: "-mentioned")

    let mergeable = CommandLine.argument(exists: "-mergeable")
    let conflict = CommandLine.argument(exists: "-conflict")

    let red = CommandLine.argument(exists: "-red")
    let green = CommandLine.argument(exists: "-green")

    let olderThan = Int(CommandLine.value(for: "-before") ?? "")
    let youngerThan = Int(CommandLine.value(for: "-within") ?? "")

    let unReviewed = CommandLine.argument(exists: "-unreviewed")
    let approved = CommandLine.argument(exists: "-approved")
    let blocked = CommandLine.argument(exists: "-blocked")

    let numbers: [Int]?

    var filteringApplied: Bool {
        author != nil
            || title != nil
            || body != nil
            || comment != nil
            || label != nil
            || milestone != nil
            || numbers != nil
            || mine
            || participated
            || mentioned
            || mergeable
            || conflict
            || red
            || green
            || unReviewed
            || approved
            || blocked
            || olderThan != nil
            || youngerThan != nil
    }

    private let refDate: Date?

    init() {
        if let d = olderThan {
            refDate = Date(timeIntervalSinceNow: -24.0 * 3600.0 * TimeInterval(d))
        } else if let d = youngerThan {
            refDate = Date(timeIntervalSinceNow: -24.0 * 3600.0 * TimeInterval(d))
        } else {
            refDate = nil
        }

        if let ns = CommandLine.value(for: "-number") {
            numbers = ns.split(separator: ",").compactMap { Int($0) }
        } else {
            numbers = nil
        }
    }

    func dateValid(for date: Date) -> Bool {
        if olderThan != nil, let refDate {
            return date <= refDate
        } else if youngerThan != nil, let refDate {
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
            if a.onlyEmpty, r.pullRequests.count > 0 || r.issues.count > 0 {
                return false
            }
            if a.hideEmpty, r.visibility == .hidden || (r.pullRequests.isEmpty && r.issues.isEmpty) {
                return false
            }
            if a.onlyActive, r.visibility == .hidden {
                return false
            }
            if a.onlyInactive, r.visibility != .hidden {
                return false
            }

            return true

        }.sorted { $0.nameWithOwner < $1.nameWithOwner }
    }

    static func pullRequestsToScan(number: Int? = nil) -> [PullRequest] {
        let allItems = reposToScan
            .filter { $0.visibility == .visible || $0.visibility == .onlyPrs }
            .reduce([PullRequest]()) { $0 + $1.pullRequests }

        let a = ItemFilterArgs()

        if !a.filteringApplied, number == nil {
            return allItems
        }

        return allItems.filter { p in

            if a.red || a.green {
                if a.red, !p.isRed {
                    return false
                }
                if a.green, !p.isGreen {
                    return false
                }
            }

            if a.mergeable && p.mergeable != .mergeable {
                return false
            }

            if a.conflict && p.mergeable != .conflicting {
                return false
            }

            if let number, p.number != number {
                return false
            }

            if let numbers = a.numbers, !numbers.contains(p.number) {
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

            if let l = a.milestone, !(p.milestone?.title.localizedCaseInsensitiveContains(l) ?? false) {
                return false
            }

            if !a.dateValid(for: p.updatedAt) {
                return false
            }

            if a.mine || a.participated || a.mentioned {
                var inSection = false
                if a.mine, p.viewerDidAuthor || p.isAssignedToMe {
                    inSection = true
                }
                if a.participated, !inSection, p.commentedByMe {
                    inSection = true
                }
                if a.mentioned, !inSection, p.mentionsMe {
                    inSection = true
                }
                if !inSection {
                    return false
                }
            }

            if let b = a.body, !p.bodyText.localizedCaseInsensitiveContains(b) {
                return false
            }

            if let c = a.comment, !p.commentsOrReviewsInclude(text: c) {
                return false
            }

            if a.unReviewed || a.approved || a.blocked {
                let pending = p.pendingReview

                if a.unReviewed, !pending {
                    return false
                }

                if a.approved, pending || !p.allReviewersApprove {
                    return false
                }

                if a.blocked, pending || !p.someReviewersBlock {
                    return false
                }
            }

            return true
        }
    }

    static func issuesToScan(number: Int? = nil) -> [Issue] {
        let allItems = reposToScan
            .filter { $0.visibility == .visible || $0.visibility == .onlyIssues }
            .reduce([Issue]()) { $0 + $1.issues }

        let a = ItemFilterArgs()
        if !a.filteringApplied && number == nil {
            return allItems
        }

        if a.mergeable || a.conflict || a.red || a.green || a.approved || a.unReviewed || a.blocked {
            return []
        }

        return allItems.filter { i in

            if let number, i.number != number {
                return false
            }

            if let numbers = a.numbers, !numbers.contains(i.number) {
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

            if let l = a.milestone, !(i.milestone?.title.localizedCaseInsensitiveContains(l) ?? false) {
                return false
            }

            if !a.dateValid(for: i.updatedAt) {
                return false
            }

            if a.mine || a.participated || a.mentioned {
                var inSection = false
                if a.mine, i.viewerDidAuthor || i.isAssignedToMe {
                    inSection = true
                }
                if a.participated, !inSection, i.commentedByMe {
                    inSection = true
                }
                if a.mentioned, !inSection, i.mentionsMe {
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
        }
    }
}
