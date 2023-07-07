import Foundation
import TrailerJson

struct BatchGroup: Ingesting {
    let name = "nodes"

    typealias NodeBlock = (JSON) -> Void

    private let idsToGroups: [String: Group]
    private let originalTemplate: Group
    private let nextCount: Int
    private let perNodeBlock: NodeBlock?

    init(templateGroup: Group, idList: [String], startingCount: Int = 0, perNodeBlock: NodeBlock? = nil) {
        self.perNodeBlock = perNodeBlock
        originalTemplate = templateGroup
        var index = startingCount

        var id2g = [String: Group]()
        id2g.reserveCapacity(idList.count)
        for id in idList {
            id2g[id] = Group(group: templateGroup, name: "\(templateGroup.name)\(index)")
            index += 1
        }
        idsToGroups = id2g
        nextCount = index
    }

    var queryText: String {
        if let templateGroup = idsToGroups.values.first {
            return "nodes(ids: [\"" + pageOfIds.joined(separator: "\",\"") + "\"]) { " + templateGroup.fields.map(\.queryText).joined(separator: " ") + " }"
        } else {
            return ""
        }
    }

    var fragments: LinkedList<Fragment> {
        let fragments = LinkedList<Fragment>()
        for f in idsToGroups.values {
            fragments.append(contentsOf: f.fragments)
        }
        return fragments
    }

    private var pageOfIds: [String] {
        let k = idsToGroups.keys.sorted()
        let max = min(config.pageSize, k.count)
        return [String](k[0 ..< max])
    }

    func ingest(query: Query, pageData: Any, parent: Parent?, level: Int) -> LinkedList<Query> {
        log(level: .debug, indent: level, "Ingesting batch group \(name)")
        guard let nodes = pageData as? [Any] else { return LinkedList<Query>() }

        let extraQueries = LinkedList<Query>()

        let page = pageOfIds
        let newIds = idsToGroups.keys.filter { !page.contains($0) }
        if newIds.hasItems {
            let nextPage = Query(name: query.name, rootElement: BatchGroup(templateGroup: originalTemplate, idList: newIds, startingCount: nextCount, perNodeBlock: perNodeBlock), parent: parent, subQuery: true)
            extraQueries.append(nextPage)
        }

        for n in nodes {
            if let n = n as? JSON, let id = n["id"] as? String, let group = idsToGroups[id] {
                let newQueries = group.ingest(query: query, pageData: n, parent: parent, level: level + 1)
                extraQueries.append(contentsOf: newQueries)
                perNodeBlock?(n)
            }
        }

        if extraQueries.count > 0 {
            log(level: .debug, indent: level, "\(name) will need further paging")
        }
        return extraQueries
    }
}
