import Foundation
import TrailerJson

typealias JSON = [String: Any]

protocol Item: Identifiable, Databaseable, Equatable {
    static var allItems: [String: Self] { get set }
    static func parse(parent: Parent?, elementType: String, node: JSON, level: Int) -> Self?
    static var idField: String { get }

    init?(id: String, type: String, node: JSON)

    var parents: [String: LinkedList<Relationship>] { get set }
    mutating func apply(_ node: JSON) -> Bool
    mutating func setChildrenSyncStatus(_ status: SyncState)
}

extension Item {
    static func setSyncStatus(_ status: SyncState, andChildren: Bool, limitToIds: [String]? = nil) {
        allItems = allItems.mapValues { item in
            if let l = limitToIds, !l.contains(item.id) {
                return item
            } else {
                var i = item
                i.setSyncStatus(status, andChildren: andChildren)
                return i
            }
        }
    }

    mutating func setSyncStatus(_ status: SyncState, andChildren: Bool) {
        syncState = status
        parents = parents.mapValues { relationshipsToAType -> LinkedList<Relationship> in
            let res = LinkedList<Relationship>()
            for n in relationshipsToAType {
                var n = n
                n.syncState = status
                res.append(n)
            }
            return res
        }
        if andChildren {
            setChildrenSyncStatus(status)
        }
    }

    private static var dataURL: URL {
        config.saveLocation.appendingPathComponent("\(typeName).json", isDirectory: false)
    }

    private static func checkItemExists(type: String, id: String) -> Bool {
        switch type {
        case "Org": return Org.allItems.keys.contains(id)
        case "Repo": return Repo.allItems.keys.contains(id)
        case "Comment": return Comment.allItems.keys.contains(id)
        case "User": return User.allItems.keys.contains(id)
        case "Reaction": return Reaction.allItems.keys.contains(id)
        case "PullRequest": return PullRequest.allItems.keys.contains(id)
        case "Issue": return Issue.allItems.keys.contains(id)
        case "Label": return Label.allItems.keys.contains(id)
        case "Review": return Review.allItems.keys.contains(id)
        case "ReviewRequest": return ReviewRequest.allItems.keys.contains(id)
        case "Status": return Status.allItems.keys.contains(id)
        case "Milestone": return Milestone.allItems.keys.contains(id)
        default: return false
        }
    }

    static func purgeStaleRelationships() {
        allItems = allItems.mapValues { item in
            var newItem = item
            for (relationshipKey, previousRelationships) in item.parents {
                let P = relationshipKey.split(separator: ":")
                let parentTypeName = String(P.first!)
                let parentField = String(P.last!)

                let newRelationships = LinkedList<Relationship>()
                for relationship in previousRelationships {
                    if relationship.syncState == .none {
                        log(level: .debug, "Removing stale relationship from \(item.typeName) \(item.id) to parent ID \(relationship.parentId)")
                        DB.removeChild(id: item.id, from: relationship.parentId, field: parentField)

                    } else if checkItemExists(type: parentTypeName, id: relationship.parentId) { // object actually exists
                        var newRelationship = relationship
                        newRelationship.syncState = .none
                        newRelationships.append(newRelationship)

                    } else {
                        log(level: .debug, "Removing relationship from \(item.typeName) \(item.id) to parent ID \(relationship.parentId) which no longer exists")
                        DB.removeChild(id: item.id, from: relationship.parentId, field: parentField)
                    }
                }
                newItem.parents[relationshipKey] = newRelationships
            }
            return newItem
        }
    }

    static func purgeUntouchedItems() {
        var purgedItemCount = 0
        for id in allItems.keys {
            guard let item = allItems[id] else { continue }
            let s = item.syncState
            if s == .none {
                log(level: .debug, "\(typeName) \(id) no longer present in server data")
                purgedItemCount += 1
                DB.removeParent(item)
            } else if s == .updated, let i = item as? Closeable, i.shouldAnnounceClosure {
                log(level: .debug, "\(typeName) \(id) is closed or merged, will remove")
                i.announceClosure()
                purgedItemCount += 1
                DB.removeParent(item)
            }
        }

        if purgedItemCount > 0 {
            log(level: .verbose, "Purged \(purgedItemCount) \(typeName) item(s) after update")
        }
    }

    static func processAnnouncements(notificationMode: NotificationMode) {
        allItems.values.forEach {
            if let i = $0 as? Announceable {
                i.announceIfNeeded(notificationMode: notificationMode)
            }
        }
    }

    static func saveAll(using encoder: JSONEncoder) {
        var newItemCount = 0
        allItems = allItems.mapValues {
            if $0.syncState == .new {
                newItemCount += 1
                log(level: .debug, "Created \(typeName) \($0.id)")
                var new = $0
                new.syncState = .none
                return new
            } else {
                return $0
            }
        }
        if newItemCount > 0 {
            log(level: .verbose, "Created \(newItemCount) \(typeName) item(s) after update")
        }

        do {
            let data = try encoder.encode(allItems)
            try data.write(to: dataURL)
        } catch {
            log("Error saving to \(dataURL)")
        }
    }

    static func loadAll(using decoder: JSONDecoder) {
        allItems.removeAll()
        guard let d = try? Data(contentsOf: dataURL) else {
            return
        }
        do {
            allItems = try decoder.decode([String: Self].self, from: d)
        } catch {
            log("Could not load data for type [*\(typeName)*]")
            allItems = [String: Self]()
        }
    }

    mutating func makeChild(of parent: Parent, indent level: Int, quiet: Bool = false) {
        let relationship = Relationship(to: parent)
        let storedField = "\(parent.item.typeName):\(parent.field)"
        if let existingRelationships = parents[storedField] {
            if existingRelationships.remove(first: { $0 == relationship }) {
                existingRelationships.append(relationship)
                if !quiet { log(level: .debug, indent: level, "Already linked to this parent in relationship '\(parent.field)'") }
            } else {
                existingRelationships.append(relationship)
                DB.addChild(id: id, to: parent)
                if !quiet { log(level: .debug, indent: level, "Adding another link to the existing parent(s) in relationship '\(parent.field)'") }
            }
        } else {
            parents[storedField] = LinkedList(value: relationship)
            DB.addChild(id: id, to: parent)
            if !quiet { log(level: .debug, indent: level, "Linking to parent through relationship '\(parent.field)'") }
        }
    }

    static func parse(parent: Parent?, elementType: String, node: JSON, level: Int) -> Self? {
        guard let id = node[Self.idField] as? String else { return nil }

        if var ret = existingItem(with: id) {
            log(level: .debug, indent: level, "Existing \(typeName) ID \(ret.id)")
            if let parent {
                ret.makeChild(of: parent, indent: level)
            }
            if !ret.apply(node) {
                log(level: .debug, indent: level, "Was placeholder data, skipped update")
            }
            if ret.syncState != .new {
                ret.syncState = .updated
            }
            allItems[id] = ret
            return ret
        } else {
            if var new = Self(id: id, type: elementType, node: node) {
                log(level: .debug, indent: level, "+ \(typeName): \(id)")
                if let parent {
                    new.makeChild(of: parent, indent: level)
                }
                allItems[id] = new
                return new
            } else {
                log(level: .debug, indent: level, "Was placeholder data, skipping creation")
                return nil
            }
        }
    }

    static func existingItem(with id: String) -> Self? {
        Self.allItems[id]
    }

    func children<T: Item>(field: String) -> [T] {
        if let childrenIds = DB.idsForChildren(of: id, field: field) {
            return childrenIds.compactMap { T.allItems[$0] }
        } else {
            return []
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
