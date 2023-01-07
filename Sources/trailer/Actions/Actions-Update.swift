//
//  Actions-Update.swift
//  trailer
//
//  Created by Paul Tsochantaris on 26/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import AsyncHTTPClient
import Foundation

enum UpdateType {
    case repos, prs, issues, comments, reactions
}

extension Actions {
    static func failUpdate(_ message: String?) {
        printErrorMesage(message)
        printOptionHeader("Please provide one of the following options for 'update'")
        printOption(name: "all", description: "Update all items")
        log()

        printOptionHeader("Instead of 'all' you can combine the following")
        printOption(name: "repos", description: "Update repository list")
        printOption(name: "items", description: "Update PRs and Issues")
        printOption(name: "prs", description: "Update PRs only")
        printOption(name: "issues", description: "Update issues only")
        printOption(name: "comments", description: "Update comments on items")
        printOption(name: "reactions", description: "Update reactions for items and comments")
        log()
        log("[!Updating options!]")
        printOption(name: "-n", description: "List new comments and reviews on items")
        printOption(name: "-from <repo>", description: "Only update items from a repo whose name includes this text")
        printOption(name: "-dryrun", description: "Perform all actions but do not save any of the changes")
        printOption(name: "-fresh", description: "Only keep what's downloaded in this sync and purge all other types of data")
        log()
        printOptionHeader("You can also update specific (existing) items by filtering:")
        log()
        printFilterOptions()
        log()
    }

    private static func updateCheck(alwaysCheck: Bool) async -> (String?, Bool) {
        var newVersion: String?
        var success = false
        if alwaysCheck || config.lastUpdateCheckDate.timeIntervalSinceNow < -3600 {
            let versionRequest = HTTPClientRequest(url: "https://api.github.com/repos/ptsochantaris/trailer-cli/releases/latest")
            if
                let data = try? await Network.getData(for: versionRequest).0,
                let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [AnyHashable: Any],
                let tagName = json["tag_name"] as? String {
                success = true
                if config.isNewer(tagName) {
                    newVersion = tagName
                }
            }
        }
        config.lastUpdateCheckDate = Date()
        return (newVersion, success)
    }

    static func checkForUpdates(reportError _: Bool, alwaysCheck: Bool) async {
        let (newVersion, success) = await updateCheck(alwaysCheck: alwaysCheck)
        if let newVersion {
            log("[![G*New Trailer version \(newVersion) is available*]!]")
        } else if !success {
            log("[R*(Latest version check failed)*]")
        }
    }

    static func processUpdateDirective(_ list: [String]) async throws {
        guard list.count > 1 else {
            failUpdate("Need at least one update type. If in doubt, use 'all'.")
            return
        }

        var updateTypes = [UpdateType]()
        for param in list.dropFirst() {
            switch param {
            case "all":
                updateTypes.append(.repos)
                updateTypes.append(.prs)
                updateTypes.append(.issues)
                updateTypes.append(.comments)
                updateTypes.append(.reactions)

            case "repos": updateTypes.append(.repos)
            case "prs": updateTypes.append(.prs)
            case "issues": updateTypes.append(.issues)
            case "items": updateTypes.append(.prs); updateTypes.append(.issues)
            case "comments": updateTypes.append(.comments)
            case "reactions": updateTypes.append(.reactions)

            case "help":
                log()
                failUpdate(nil)
                return

            default:
                failUpdate("Unknown argmument: \(param)")
                return
            }
        }
        if !updateTypes.isEmpty {
            try await update(updateTypes,
                             limitToRepoNames: CommandLine.value(for: "-from"),
                             keepOnlyNewItems: CommandLine.argument(exists: "-fresh"))
        } else {
            log()
            failUpdate("Need at least one update type. If in doubt, use 'all'.")
        }
    }

    static func testToken() async throws {
        let testQuery = Query(name: "Test", rootElement:
            Group(name: "viewer", fields: [
                User.fragment
            ]))
        try await testQuery.run()
        log("Token for server [*\(config.server.absoluteString)*] is valid: Account is [*\(config.myLogin)*]")
    }

    private static func update(_ typesToSync: [UpdateType], limitToRepoNames: String?, keepOnlyNewItems: Bool) async throws {
        let repoFilters = RepoFilterArgs()
        let itemFilters = ItemFilterArgs()
        let filtersRequested = repoFilters.filteringApplied || itemFilters.filteringApplied

        let userWantsRepos = typesToSync.contains(.repos) && !filtersRequested && limitToRepoNames == nil
        let userWantsPrs = typesToSync.contains(.prs)
        let userWantsIssues = typesToSync.contains(.issues)
        let userWantsComments = typesToSync.contains(.comments)
        let userWantsReactions = typesToSync.contains(.reactions)

        if !(userWantsRepos || userWantsPrs || userWantsIssues || userWantsComments || userWantsReactions) {
            failUpdate("This combination of parameters will not cause anything to be updated")
            exit(1)
        }

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////

        async let (latestVersion, _) = updateCheck(alwaysCheck: false)

        await DB.load()
        if let d = config.latestSyncDate {
            log(agoFormat(prefix: "[!Last update was ", since: d) + "!]")
        }
        log("Starting update...")
        config.totalQueryCosts = 0

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////

        if userWantsRepos {
            let repositoryListQuery = Query(name: "Repos", rootElement:
                Group(name: "viewer", fields: [
                    User.fragment,
                    Group(name: "organizations", fields: [Org.fragmentWithRepos], paging: .largePage),
                    Group(name: "repositories", fields: [Repo.fragment], paging: .largePage),
                    Group(name: "watching", fields: [Repo.fragment], paging: .largePage)
                ]))
            try await repositoryListQuery.run()
        } else {
            log(level: .info, "[*Repos*] (Skipped)")
            Org.setSyncStatus(.updated, andChildren: false)
            Repo.setSyncStatus(.updated, andChildren: false)
        }

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////

        var prIdList = [String: String]() // existing PRs
        if userWantsPrs {
            for p in pullRequestsToScan() {
                if let r = p.repo, r.shouldSyncPrs {
                    if let rf = limitToRepoNames {
                        prIdList[p.id] = r.nameWithOwner.localizedCaseInsensitiveContains(rf) ? r.id : nil
                    } else {
                        prIdList[p.id] = r.id
                    }
                }
            }
        }

        var issueIdList = [String: String]() // existing Issues
        if userWantsIssues {
            for i in issuesToScan() {
                if let r = i.repo, r.shouldSyncIssues {
                    if let rf = limitToRepoNames {
                        issueIdList[i.id] = r.nameWithOwner.localizedCaseInsensitiveContains(rf) ? r.id : nil
                    } else {
                        issueIdList[i.id] = r.id
                    }
                }
            }
        }

        if userWantsPrs || userWantsIssues, !filtersRequested { // detect new items
            let itemIdParser = { (node: [AnyHashable: Any]) in

                guard let repoId = node["id"] as? String else {
                    return
                }

                var syncPrs = true
                var syncIssues = true
                if let repo = Repo.allItems[repoId] {
                    if repo.syncState == .none {
                        return
                    }

                    switch repo.visibility {
                    case .hidden:
                        return
                    case .onlyIssues:
                        syncPrs = false
                    case .onlyPrs:
                        syncIssues = false
                    case .visible:
                        break
                    }
                }

                if syncPrs, let section = node["pullRequests"] as? [AnyHashable: Any], let itemList = section["edges"] as? [[AnyHashable: Any]] {
                    for p in itemList {
                        if let node = p["node"] as? [AnyHashable: Any], let id = node["id"] as? String {
                            prIdList[id] = repoId
                            log(level: .debug, indent: 1, "Registered PR ID: \(id)")
                        }
                    }
                }

                if syncIssues, let section = node["issues"] as? [AnyHashable: Any], let itemList = section["edges"] as? [[AnyHashable: Any]] {
                    for p in itemList {
                        if let node = p["node"] as? [AnyHashable: Any], let id = node["id"] as? String {
                            issueIdList[id] = repoId
                            log(level: .debug, indent: 1, "Registered Issue ID: \(id)")
                        }
                    }
                }
            }

            let repoIds: [String]
            if let rf = limitToRepoNames {
                repoIds = Repo.allItems.values.compactMap { ($0.visibility == .hidden || !$0.nameWithOwner.localizedCaseInsensitiveContains(rf)) ? nil : $0.id }
            } else {
                repoIds = Repo.allItems.values.compactMap { $0.visibility == .hidden ? nil : $0.id }
            }
            let fields =
                (userWantsPrs && userWantsIssues) ? [Repo.prAndIssueIdsFragment] :
                userWantsPrs ? [Repo.prIdsFragment] :
                userWantsIssues ? [Repo.issueIdsFragment] :
                []
            let itemQueries = Query.batching("Item IDs", fields: fields, idList: repoIds, perNodeBlock: itemIdParser)
            try await Query.attempt(itemQueries)
        } else {
            log(level: .info, "[*Item IDs*] (Skipped)")
        }

        if !keepOnlyNewItems {
            if !userWantsPrs || filtersRequested || limitToRepoNames != nil { // do not expire items which are not included in this sync
                let limitIds = PullRequest.allItems.keys.filter { issueIdList[$0] == nil }
                PullRequest.setSyncStatus(.updated, andChildren: true, limitToIds: limitIds)
            }

            if !userWantsIssues || filtersRequested || limitToRepoNames != nil { // do not expire items which are not included in this sync
                let limitIds = Issue.allItems.keys.filter { issueIdList[$0] == nil }
                Issue.setSyncStatus(.updated, andChildren: true, limitToIds: limitIds)
            }
        }

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////

        if prIdList.count > 0 {
            let fragment = userWantsComments ? PullRequest.fragmentWithComments : PullRequest.fragment
            let prQueries = Query.batching("PRs", fields: [fragment], idList: Array(prIdList.keys))
            try await Query.attempt(prQueries)

            if !userWantsRepos { // revitalise links to parent repos for updated items
                let updatedPrs = PullRequest.allItems.values.filter { $0.syncState == .updated }
                for pr in updatedPrs {
                    if let repo = pr.repo, let parent = Parent(item: repo, field: "pullRequests") {
                        var newPr = pr
                        newPr.makeChild(of: parent, indent: 1, quiet: true)
                        PullRequest.allItems[pr.id] = newPr
                    }
                }
            }

            let prsMissingParents = PullRequest.allItems.values.filter { $0.repo == nil }
            for pr in prsMissingParents {
                let prId = pr.id
                log(level: .debug, indent: 1, "Detected missing parent for PR ID '\(prId)'")
                if let repoIdForPr = prIdList[prId], let repo = Repo.allItems[repoIdForPr] {
                    log(level: .debug, indent: 1, "Determined parent should be Repo ID '\(repoIdForPr)'")
                    if let parent = Parent(item: repo, field: "pullRequests") {
                        var newPr = pr
                        newPr.makeChild(of: parent, indent: 1)
                        PullRequest.allItems[prId] = newPr
                    }
                }
            }
        } else {
            log(level: .info, "[*PRs*] (Skipped)")
        }

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////

        if userWantsPrs, userWantsComments {
            let reviewIdsWithComments = Review.allItems.values.compactMap { $0.syncState == .none || !$0.syncNeedsComments ? nil : $0.id }

            if reviewIdsWithComments.count > 0 {
                try await Query.attempt(Query.batching("PR Review Comments", fields: [
                    Review.commentsFragment,
                    PullRequest.commentsFragment,
                    Issue.commentsFragment
                ], idList: reviewIdsWithComments))
            } else {
                log(level: .info, "[*PR Review Comments*] (Skipped)")
            }

        } else {
            log(level: .info, "[*PR Review Comments*] (Skipped)")
            if !keepOnlyNewItems {
                let reviewCommentIds = Review.allItems.values.reduce([String]()) { idList, review -> [String] in
                    idList + review.comments.map(\.id)
                }
                Comment.setSyncStatus(.updated, andChildren: true, limitToIds: reviewCommentIds)
            }
        }

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////

        if issueIdList.count > 0 {
            let fragment = userWantsComments ? Issue.fragmentWithComments : Issue.fragment
            let issueQueries = Query.batching("Issues", fields: [fragment], idList: Array(issueIdList.keys))
            try await Query.attempt(issueQueries)

            if !userWantsRepos { // revitalise links to parent repos for updated items
                let updatedIssues = Issue.allItems.values.filter { $0.syncState == .updated }
                for issue in updatedIssues {
                    if let repo = issue.repo, let parent = Parent(item: repo, field: "issues") {
                        var newIssue = issue
                        newIssue.makeChild(of: parent, indent: 1, quiet: true)
                        Issue.allItems[issue.id] = newIssue
                    }
                }
            }

            let issuesMissingParents = Issue.allItems.values.filter { $0.repo == nil }
            for issue in issuesMissingParents {
                let issueId = issue.id
                log(level: .debug, indent: 1, "Detected missing parent for Issue ID '\(issueId)'")
                if let repoIdForIssue = issueIdList[issueId], let repo = Repo.allItems[repoIdForIssue] {
                    log(level: .debug, indent: 1, "Determined parent should be Repo ID '\(repoIdForIssue)'")
                    if let parent = Parent(item: repo, field: "issues") {
                        var newIssue = issue
                        newIssue.makeChild(of: parent, indent: 1)
                        Issue.allItems[issueId] = newIssue
                    }
                }
            }
        } else {
            log(level: .info, "[*Issues*] (Skipped)")
        }

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////

        if !keepOnlyNewItems, !userWantsComments {
            var itemIds = [String]()

            for p in PullRequest.allItems.values.filter({ $0.syncState == .updated }) {
                itemIds += p.comments.map(\.id)
            }

            for p in Issue.allItems.values.filter({ $0.syncState == .updated }) {
                itemIds += p.comments.map(\.id)
            }

            if !itemIds.isEmpty {
                Comment.setSyncStatus(.updated, andChildren: true, limitToIds: itemIds)
            }
        }

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////

        if userWantsReactions {
            var itemIdsWithReactions = [String]()

            if userWantsComments {
                itemIdsWithReactions += Comment.allItems.values.compactMap { ($0.syncState == .none || !$0.syncNeedsReactions) ? nil : $0.id }
            } else {
                itemIdsWithReactions += Comment.allItems.keys
            }

            if userWantsPrs {
                itemIdsWithReactions += PullRequest.allItems.values.compactMap { ($0.syncState == .none || !$0.syncNeedsReactions) ? nil : $0.id }
            } else {
                itemIdsWithReactions += PullRequest.allItems.keys
            }

            if userWantsIssues {
                itemIdsWithReactions += Issue.allItems.values.compactMap { ($0.syncState == .none || !$0.syncNeedsReactions) ? nil : $0.id }
            } else {
                itemIdsWithReactions += Issue.allItems.keys
            }

            try await Query.attempt(Query.batching("Reactions", fields: [
                Comment.pullRequestReviewCommentReactionFragment,
                Comment.issueCommentReactionFragment,
                PullRequest.reactionsFragment,
                Issue.reactionsFragment
            ], idList: itemIdsWithReactions))

        } else {
            log(level: .info, "[*Reactions*] (Skipped)")
            if !keepOnlyNewItems {
                Reaction.setSyncStatus(.updated, andChildren: true)
            }
        }

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////

        if !config.dryRun {
            config.latestSyncDate = Date()
        }

        let n: NotificationMode = CommandLine.argument(exists: "-n") ? .consoleCommentsAndReviews : .standard
        await DB.save(purgeUntouchedItems: true, notificationMode: n)
        Notifications.processQueue()
        log("Update done.")
        if config.totalQueryCosts > 0 {
            log(level: .verbose, "Total update API cost: \(config.totalQueryCosts)")
        }
        if config.totalApiRemaining < Int.max {
            log(level: .verbose, "Remaining API limit: \(config.totalApiRemaining)")
        }
        if let l = await latestVersion {
            log("[![G*New Trailer version \(l) is available*]!]")
        }
    }

    static func singleItemUpdate(for item: ListableItem) async throws -> ListableItem {
        let userWantsComments = CommandLine.argument(exists: "-comments")
        if let pr = item.pullRequest {
            let fragment = userWantsComments ? PullRequest.fragmentWithComments : PullRequest.fragment
            let queries = Query.batching("PR", fields: [fragment], idList: [pr.id])
            try await Query.attempt(queries)

            if userWantsComments {
                let reviewIdsWithComments = pr.reviews.compactMap { $0.syncState == .none || !$0.syncNeedsComments ? nil : $0.id }
                if reviewIdsWithComments.count > 0 {
                    try await Query.attempt(Query.batching("PR Review Comments", fields: [
                        Review.commentsFragment,
                        PullRequest.commentsFragment,
                        Issue.commentsFragment
                    ], idList: reviewIdsWithComments))
                }
            }

            var itemIdsWithReactions = [pr.id]
            if userWantsComments {
                itemIdsWithReactions += pr.comments.compactMap { ($0.syncState == .none || !$0.syncNeedsReactions) ? nil : $0.id }
                for review in pr.reviews {
                    itemIdsWithReactions.append(contentsOf: review.comments.compactMap { ($0.syncState == .none || !$0.syncNeedsReactions) ? nil : $0.id })
                }
            }
            try await Query.attempt(Query.batching("Reactions", fields: [
                Comment.pullRequestReviewCommentReactionFragment,
                PullRequest.reactionsFragment
            ], idList: itemIdsWithReactions))

            await DB.save(purgeUntouchedItems: false, notificationMode: .none)
            return ListableItem.pullRequest(PullRequest.allItems[pr.id]!)

        } else if let issue = item.issue {
            let fragment = userWantsComments ? Issue.fragmentWithComments : Issue.fragment
            let queries = Query.batching("Issue", fields: [fragment], idList: [issue.id])
            try await Query.attempt(queries)

            var itemIdsWithReactions = [issue.id]
            if userWantsComments {
                itemIdsWithReactions += issue.comments.compactMap { ($0.syncState == .none || !$0.syncNeedsReactions) ? nil : $0.id }
            }

            try await Query.attempt(Query.batching("Reactions", fields: [
                Comment.pullRequestReviewCommentReactionFragment,
                PullRequest.reactionsFragment
            ], idList: itemIdsWithReactions))

            await DB.save(purgeUntouchedItems: false, notificationMode: .none)
            return ListableItem.issue(Issue.allItems[issue.id]!)
        }
        return item
    }
}
