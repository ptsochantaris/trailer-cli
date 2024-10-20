import Foundation

@MainActor
protocol DetailPrinter {
    var createdAt: Date { get set }
    func printDetails()
}
