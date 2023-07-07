import Foundation

struct Parent {
    let item: Identifiable
    let field: String
    init?(item: Identifiable?, field: String?) {
        self.field = field ?? "NOFIELD"
        if let i = item {
            self.item = i
        } else {
            return nil
        }
    }
}
