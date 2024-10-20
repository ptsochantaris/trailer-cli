import Foundation

@MainActor
protocol Databaseable {
    static func saveAll(using encoder: JSONEncoder) async
    static func loadAll(using decoder: JSONDecoder) async
    static func processAnnouncements(notificationMode: NotificationMode)
    static func purgeUntouchedItems()
    static func purgeStaleRelationships()
}
