import Foundation
import TrailerQL

@MainActor
struct Parent {
    let item: Identifiable
    let field: String

    init?(of node: Node) {
        guard let parent = node.parent,
              let field = node.relationship,
              let item = DB.lookup(type: parent.elementType, id: parent.id)
        else {
            return nil
        }

        self.item = item
        self.field = field
    }

    init(item: Identifiable, field: String) {
        self.item = item
        self.field = field
    }
}
