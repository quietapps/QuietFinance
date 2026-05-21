import Foundation
import SwiftData

@Model
final class Receivable {
    @Attribute(.unique) var id: UUID
    var name: String
    var debtor: String
    var nativeCurrency: Currency
    var notes: String
    var isActive: Bool
    var createdAt: Date
    var startDate: Date = Date.distantPast

    @Relationship(deleteRule: .cascade, inverse: \ReceivableValue.receivable)
    var values: [ReceivableValue] = []

    init(name: String,
         debtor: String = "",
         nativeCurrency: Currency = .USD,
         notes: String = "",
         isActive: Bool = true,
         startDate: Date = .now) {
        self.id = UUID()
        self.name = name
        self.debtor = debtor
        self.nativeCurrency = nativeCurrency
        self.notes = notes
        self.isActive = isActive
        self.createdAt = .now
        self.startDate = startDate
    }
}
