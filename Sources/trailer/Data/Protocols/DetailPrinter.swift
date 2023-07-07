import Foundation

protocol DetailPrinter {
    var createdAt: Date { get set }
    func printDetails()
}
