import Foundation
import Lista
import TrailerJson

@MainActor
protocol Item: Identifiable, Databaseable, Equatable {
    static var allItems: [String: Self] { get set }

    static func parse(parent: Parent?, elementType: String, node: TypedJson.Entry, level: Int) -> Self?

    init?(id: String, type: String, node: TypedJson.Entry)

    var parents: [String: Lista<Relationship>] { get set }
    mutating func apply(_ node: TypedJson.Entry) -> Bool
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
        parents = parents.mapValues { relationshipsToAType -> Lista<Relationship> in
            let res = Lista<Relationship>()
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
        DB.lookup(type: type, id: id) != nil
    }

    @MainActor
    static func purgeStaleRelationships() {
        allItems = allItems.mapValues { item in
            var newItem = item
            for (relationshipKey, previousRelationships) in item.parents {
                let P = relationshipKey.split(separator: ":")
                let parentTypeName = String(P.first!)
                let parentField = String(P.last!)

                let newRelationships = Lista<Relationship>()
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
        for value in allItems.values {
            if let i = value as? Announceable {
                i.announceIfNeeded(notificationMode: notificationMode)
            }
        }
    }

    static func saveAll(using encoder: JSONEncoder) async {
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

        let items = allItems
        let url = dataURL
        await Task.detached {
            do {
                let data = try encoder.encode(items)
                try data.write(to: url)
            } catch {
                await log("Error saving to \(url)")
            }
        }.value
    }

    static func loadAll(using decoder: JSONDecoder) async {
        allItems.removeAll()
        let url = dataURL
        guard let d = await Task.detached(operation: { try? Data(contentsOf: url) }).value else {
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
            parents[storedField] = Lista(value: relationship)
            DB.addChild(id: id, to: parent)
            if !quiet { log(level: .debug, indent: level, "Linking to parent through relationship '\(parent.field)'") }
        }
    }

    @discardableResult
    static func parse(parent: Parent?, elementType: String, node: TypedJson.Entry, level: Int) -> Self? {
        guard let id = node.potentialString(named: "id") else { return nil }

        if var ret = allItems[id] {
            log(level: .debug, indent: level, "Existing \(typeName) ID \(ret.id)")
            if let parent {
                ret.makeChild(of: parent, indent: level)
            } else {
                log(level: .debug, indent: level, "Does not have parent, no need to update relationship")
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

    func children<T: Item>(field: String) -> [T] {
        if let childrenIds = DB.idsForChildren(of: id, field: field) {
            childrenIds.compactMap { T.allItems[$0] }
        } else {
            []
        }
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
