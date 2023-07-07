import Foundation

protocol Ingesting: Element {
    func ingest(query: Query, pageData: Any, parent: Parent?, level: Int) -> LinkedList<Query>
}
