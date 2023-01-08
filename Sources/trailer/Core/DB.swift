//
//  Data.swift
//  trailer
//
//  Created by Paul Tsochantaris on 21/08/2017.
//  Copyright © 2017 Paul Tsochantaris. All rights reserved.
//

import Foundation

enum NotificationMode {
    case none, standard, consoleCommentsAndReviews
}

enum DB {
    private static let allTypes: [Databaseable.Type] = [
        Org.self,
        Repo.self,
        Issue.self,
        PullRequest.self,
        Milestone.self,
        Status.self,
        ReviewRequest.self,
        Label.self,
        Comment.self,
        Review.self,
        Reaction.self,
        User.self
    ]

    //////////////////////////////////// Stats

    static func printStats() async {
        await DB.load()
        log("[![*Org*]!]\t\t\(Org.allItems.count)")
        log("[![*Repo*]!]\t\t\(Repo.allItems.count)")
        log("[![*Issue*]!]\t\t\(Issue.allItems.count)")
        log("[![*PullRequest*]!]\t\(PullRequest.allItems.count)")
        log("[![*Milestone*]!]\t\(Milestone.allItems.count)")
        log("[![*Status*]!]\t\t\(Status.allItems.count)")
        log("[![*ReviewRequest*]!]\t\(ReviewRequest.allItems.count)")
        log("[![*Label*]!]\t\t\(Label.allItems.count)")
        log("[![*Comment*]!]\t\t\(Comment.allItems.count)")
        log("[![*Review*]!]\t\t\(Review.allItems.count)")
        log("[![*Reaction*]!]\t\(Reaction.allItems.count)")
        log("[![*User*]!]\t\t\(User.allItems.count)")
    }

    //////////////////////////////////// Child lookup

    private static var parents2fields2children = [String: [String: LinkedList<String>]]()

    static func idsForChildren(of itemId: String, field: String) -> LinkedList<String>? {
        parents2fields2children[itemId]?[field]
    }

    static func addChild(id: String, to parent: Parent) {
        let fieldName = parent.field
        let parentId = parent.item.id
        if var field2children = parents2fields2children[parentId] {
            if let listOfChildren = field2children[fieldName] {
                if !listOfChildren.contains(id) {
                    listOfChildren.append(id)
                }
            } else {
                field2children[fieldName] = LinkedList(value: id)
                parents2fields2children[parentId] = field2children
            }
        } else {
            var field2children = [String: LinkedList<String>]()
            field2children[fieldName] = LinkedList(value: id)
            parents2fields2children[parentId] = field2children
        }
    }

    static func removeChild(id: String, from parentId: String, field: String) {
        if var field2children = parents2fields2children[parentId] {
            if let listOfChildren = field2children[field] {
                listOfChildren.remove { $0 == id }
                if listOfChildren.count == 0 {
                    field2children[field] = nil
                    parents2fields2children[parentId] = field2children
                }
            }
        }
    }

    static func removeParent(_ item: some Item) {
        let id = item.id
        type(of: item).allItems[id] = nil
        parents2fields2children[id] = nil
    }

    ///////////////////////////////////// Load

    static func load() async {
        log(level: .debug, "Loading DB...")
        await withTaskGroup(of: Void.self) { group in
            let e = JSONDecoder()
            for type in allTypes {
                group.addTask {
                    type.loadAll(using: e)
                }
            }
            group.addTask {
                loadRelationships(using: e)
            }
        }
        log(level: .verbose, "Loaded DB")

        config.myUser = User.allItems.values.first { $0.isMe }
        if config.myUser != nil {
            log(level: .verbose, "API user is [*\(config.myLogin)*]")
        }
    }

    static var relationshipsPath: URL {
        config.saveLocation.appendingPathComponent("relationships.json", isDirectory: false)
    }

    static func loadRelationships(using decoder: JSONDecoder) {
        parents2fields2children.removeAll()
        let l = relationshipsPath
        if FileManager.default.fileExists(atPath: l.path) {
            do {
                let d = try Data(contentsOf: l)
                let temp = try decoder.decode([String: [String: LinkedList<String>]].self, from: d)
                for (parent, var fields2children) in temp {
                    for (field, children) in fields2children {
                        var ids = Set<String>()
                        let clist = LinkedList<String>()
                        for c in children where ids.insert(c).inserted {
                            clist.append(c)
                        }
                        fields2children[field] = clist
                    }
                    parents2fields2children[parent] = fields2children
                }
            } catch {
                log("Could not load data for relationships")
            }
        }
    }

    ///////////////////////////////////// Save

    static func save(purgeUntouchedItems: Bool, notificationMode: NotificationMode) async {
        log(level: .debug, "Processing Announcements...")
        allTypes.forEach { $0.processAnnouncements(notificationMode: notificationMode) }

        if purgeUntouchedItems {
            log(level: .debug, "Purging stale items...")
            allTypes.forEach { $0.purgeUntouchedItems() }
            allTypes.forEach { $0.purgeStaleRelationships() }
        }

        if config.dryRun {
            log(level: .info, "Dry run requested, updated data not saved")
            return
        }

        log(level: .debug, "Saving DB...")
        await withTaskGroup(of: Void.self) { group in
            let e = JSONEncoder()
            for type in allTypes {
                group.addTask {
                    type.saveAll(using: e)
                }
            }
            group.addTask {
                saveRelationships(using: e)
            }
        }
        log(level: .verbose, "Saved DB to \(config.saveLocation.path)/")
    }

    static func saveRelationships(using encoder: JSONEncoder) {
        let c = try! encoder.encode(parents2fields2children)
        let l = relationshipsPath
        let f = FileManager.default
        if f.fileExists(atPath: l.path) {
            try! f.removeItem(at: l)
        }
        try! c.write(to: l)
    }
}
