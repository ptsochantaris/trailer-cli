import Foundation

@MainActor
protocol Announceable: DetailPrinter {
    func announceIfNeeded(notificationMode: NotificationMode)
}
