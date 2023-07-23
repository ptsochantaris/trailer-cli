import Foundation
import TrailerQL

struct Parent {
    let item: Identifiable
    let field: String

    init?(of node: Node) {
        guard let parent = node.parent,
              let item = DB.lookup(type: parent.elementType, id: parent.id),
              let field = DB.getParentField(for: node)
        else {
            return nil
        }

        self.item = item
        self.field = field
    }

    init?(item: Identifiable?, field: String?) {
        if let item {
            self.item = item
            self.field = field ?? "NOFIELD"
        } else {
            return nil
        }
    }
}
