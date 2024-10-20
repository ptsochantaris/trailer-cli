import Foundation

@MainActor
protocol Databaseable {
    static func saveAll(using encoder: JSONEncoder)
    static func loadAll(using decoder: JSONDecoder)
    static func processAnnouncements(notificationMode: NotificationMode)
    static func purgeUntouchedItems()
    static func purgeStaleRelationships()
}
