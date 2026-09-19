import Foundation
import TrailerQL

struct Parent {
    let item: any ItemIdentity
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

    init(item: any ItemIdentity, field: String) {
        self.item = item
        self.field = field
    }
}
