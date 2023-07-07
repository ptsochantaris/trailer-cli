import Foundation

protocol Announceable: DetailPrinter {
    func announceIfNeeded(notificationMode: NotificationMode)
}
