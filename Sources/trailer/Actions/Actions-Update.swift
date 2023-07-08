import Foundation
import TrailerQL
import TrailerJson

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
            let versionRequest = Network.Request(url: "https://api.github.com/repos/ptsochantaris/trailer-cli/releases/latest", method: .get, body: nil)
            if
                let data = try? await Network.getData(for: versionRequest),
                let json = try? data.asJsonObject(),
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
        let testQuery = Query(name: "Test", rootElement: Group("viewer") {
            User.fragment
        })
        try await run(testQuery)
        log("Token for server [*\(config.server.absoluteString)*] is valid: Account is [*\(config.myLogin)*]")
    }

    private static func parse(node: Node) {
        let parent = Parent(of: node)
        let info = node.jsonPayload
        let level = 1
        
        guard let typeName = info["__typename"] as? String else {
            log(level: .debug, indent: level, "+ Warning: no typename in info to parse")
            return
        }
        
        if let parent {
            log(level: .debug, indent: level, "Scanning \(typeName) with parent \(parent.item.typeName) \(parent.item.id)")
        } else {
            log(level: .debug, indent: level, "Scanning \(typeName)")
        }
        
        switch typeName {
        case "Repository":
            Repo.parse(parent: parent, elementType: typeName, node: info, level: level)
        case "Label":
            Label.parse(parent: parent, elementType: typeName, node: info, level: level)
        case "PullRequest":
            PullRequest.parse(parent: parent, elementType: typeName, node: info, level: level)
        case "Issue":
            Issue.parse(parent: parent, elementType: typeName, node: info, level: level)
        case "IssueComment", "PullRequestReviewComment":
            Comment.parse(parent: parent, elementType: typeName, node: info, level: level)
        case "PullRequestReview":
            Review.parse(parent: parent, elementType: typeName, node: info, level: level)
        case "Reaction":
            Reaction.parse(parent: parent, elementType: typeName, node: info, level: level)
        case "User":
            let u = User.parse(parent: parent, elementType: typeName, node: info, level: level)
            guard parent == nil, var me = u else {
                return
            }
            me.isMe = true
            config.myUser = me
            User.allItems[me.id] = me
        case "ReviewRequest":
            ReviewRequest.parse(parent: parent, elementType: typeName, node: info, level: level)
        case "CheckRun", "StatusContext":
            Status.parse(parent: parent, elementType: typeName, node: info, level: level)
        case "Milestone":
            Milestone.parse(parent: parent, elementType: typeName, node: info, level: level)
        case "Organization":
            Org.parse(parent: parent, elementType: typeName, node: info, level: level)
        case "Bot", "CheckSuite", "Commit", "PullRequestCommit", "PullRequestReviewCommentConnection", "ReactionConnection", "Status":
            return
        default:
            log(level: .debug, indent: level, "+ Warning: unhandled type '\(typeName)'")
        }
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
            let root = Group("viewer") {
                User.fragment
                Group("organizations", paging: .first(count: 100, paging: true)) { Org.fragmentWithRepos }
                Group("repositories", paging: .first(count: 100, paging: true)) { Repo.fragment }
                Group("watching", paging: .first(count: 100, paging: true)) { Repo.fragment }
            }
            let repositoryListQuery = Query(name: "Repos", rootElement: root, perNode: parse)
            try await run(repositoryListQuery)
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
            let itemIdParser: Query.PerNodeBlock = { node in
                guard let parent = node.parent, parent.elementType == "Repository" else {
                    return
                }
                
                let repoId = parent.id
                guard let repo = Repo.allItems[repoId], repo.syncState != .none, repo.visibility != .hidden else {
                    return
                }
                                
                if node.elementType == "PullRequest" {
                    switch repo.visibility {
                    case .onlyPrs, .visible:
                        let id = node.id
                        prIdList[id] = repoId
                        log(level: .debug, indent: 1, "Registered PR ID: \(id)")
                    default: break
                    }
                } else if node.elementType == "Issue" {
                    switch repo.visibility {
                    case .onlyIssues, .visible:
                        let id = node.id
                        issueIdList[id] = repoId
                        log(level: .debug, indent: 1, "Registered Issue ID: \(id)")
                    default: break
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
            if !fields.isEmpty {
                let queries = Query.batching("Item IDs", idList: repoIds, perNode: itemIdParser) { fields }
                try await run(queries)
            }
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

        if !prIdList.isEmpty {
            try await run(Query.batching("PRs", idList: Array(prIdList.keys), perNode: parse) {
                userWantsComments ? PullRequest.fragmentWithComments : PullRequest.fragment
            })

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

            if !reviewIdsWithComments.isEmpty {
                try await run(Query.batching("PR Review Comments", idList: reviewIdsWithComments, perNode: parse) {
                    Review.commentsFragment
                    PullRequest.commentsFragment
                    Issue.commentsFragment
                })
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

        if !issueIdList.isEmpty {
            try await run(Query.batching("Issues", idList: Array(issueIdList.keys), perNode: parse) {
                userWantsComments ? Issue.fragmentWithComments : Issue.fragment
            })

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

            try await run(Query.batching("Reactions", idList: itemIdsWithReactions, perNode: parse) {
                Comment.pullRequestReviewCommentReactionFragment
                Comment.issueCommentReactionFragment
                PullRequest.reactionsFragment
                Issue.reactionsFragment
            })

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
            let queries = Query.batching("PR", idList: [pr.id], perNode: parse) { fragment }
            try await run(queries)

            if userWantsComments {
                let reviewIdsWithComments = pr.reviews.compactMap { $0.syncState == .none || !$0.syncNeedsComments ? nil : $0.id }
                if !reviewIdsWithComments.isEmpty {
                    try await run(Query.batching("PR Review Comments", idList: reviewIdsWithComments, perNode: parse) {
                        Review.commentsFragment
                        PullRequest.commentsFragment
                        Issue.commentsFragment
                    })
                }
            }

            var itemIdsWithReactions = [pr.id]
            if userWantsComments {
                itemIdsWithReactions += pr.comments.compactMap { ($0.syncState == .none || !$0.syncNeedsReactions) ? nil : $0.id }
                for review in pr.reviews {
                    itemIdsWithReactions.append(contentsOf: review.comments.compactMap { ($0.syncState == .none || !$0.syncNeedsReactions) ? nil : $0.id })
                }
            }
            try await run(Query.batching("Reactions", idList: itemIdsWithReactions, perNode: parse) {
                Comment.pullRequestReviewCommentReactionFragment
                PullRequest.reactionsFragment
            })

            await DB.save(purgeUntouchedItems: false, notificationMode: .none)
            return ListableItem.pullRequest(PullRequest.allItems[pr.id]!)

        } else if let issue = item.issue {
            let fragment = userWantsComments ? Issue.fragmentWithComments : Issue.fragment
            let queries = Query.batching("Issue", idList: [issue.id], perNode: parse) { fragment }
            try await run(queries)

            var itemIdsWithReactions = [issue.id]
            if userWantsComments {
                itemIdsWithReactions += issue.comments.compactMap { ($0.syncState == .none || !$0.syncNeedsReactions) ? nil : $0.id }
            }

            try await run(Query.batching("Reactions", idList: itemIdsWithReactions, perNode: parse) {
                Comment.pullRequestReviewCommentReactionFragment
                PullRequest.reactionsFragment
            })

            await DB.save(purgeUntouchedItems: false, notificationMode: .none)
            return ListableItem.issue(Issue.allItems[issue.id]!)
        }
        return item
    }
    
    private static func run(_ query: Query, shouldRetry: Int = 5, asSubQuery: Bool = false) async throws {
        func retryOrFail(_ message: String) async throws {
            if shouldRetry > 1 {
                log(level: .verbose, "[*\(query.name)*] \(message)")
                log(level: .verbose, "[*\(query.name)*] Retrying")
                try await run(query, shouldRetry: shouldRetry - 1)
            } else {
                log("[*\(query.name)*] \(message)")
                throw NSError(domain: "build.bru.trailer-cli.query", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
            }
        }
        
        func extractRateLimit(from json: JSON) -> JSON? {
            if let data = json["data"] as? JSON {
                return data["rateLimit"] as? JSON
            }
            return nil
        }
        
        if shouldRetry == 5, !asSubQuery {
            log("[*\(query.name)*] Fetching")
        }
        
        let info: Data
        do {
            let Q = query.queryText
            log(level: .debug, "[*\(query.name)*] \(Q)")
            let body = try JSONEncoder().encode(["query": Q])
            let req = Network.Request(url: config.server.absoluteString, method: .post, body: body)
            info = try await Network.getData(for: req)
        } catch {
            try await retryOrFail("Query error: \(error.localizedDescription)")
            return
        }
        
        guard let json = try info.asJsonObject() else {
            try await retryOrFail("No JSON in API response: \(String(data: info, encoding: .utf8) ?? "")")
            return
        }
        
        let extraQueries: TrailerQL.List<Query>
        do {
            extraQueries = try await query.processResponse(from: json)
            
        } catch {
            let serverError: String?
            if let errors = json["errors"] as? [JSON] {
                serverError = errors.first?["message"] as? String
            } else {
                serverError = json["message"] as? String
            }
            let resolved = serverError ?? error.localizedDescription
            try await retryOrFail("Failed with error: '\(resolved)'")
            return
        }
        
        if let rateLimit = extractRateLimit(from: json), let cost = rateLimit["cost"] as? Int, let remaining = rateLimit["remaining"] as? Int, let nodeCount = rateLimit["nodeCount"] as? Int {
            config.totalQueryCosts += cost
            config.totalApiRemaining = min(config.totalApiRemaining, remaining)
            log(level: .verbose, "[*\(query.name)*] Processed page (Cost: [!\(cost)!], Remaining: [!\(remaining)!] - Node Count: [!\(nodeCount)!])")
        } else {
            log(level: .verbose, "[*\(query.name)*] Processed page")
        }
                
        if extraQueries.count == 0 {
            return
        }
        
        log(level: .debug, "[*\(query.name)*] Needs more page data")
        try await run(extraQueries, asSubQueries: true)
    }
    
    private static func run(_ queries: TrailerQL.List<Query>, asSubQueries: Bool = false) async throws {
        for query in queries {
            try await run(query, asSubQuery: asSubQueries)
        }
    }
}
