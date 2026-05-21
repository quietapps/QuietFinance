import Foundation
import SwiftData

@Model
final class Person {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String?
    var createdAt: Date
    /// If false, this person's accounts are tracked but excluded from net-worth
    /// totals, KPIs, breakdowns, charts, and forecasts. Used to track a parent
    /// or partner whose finances live alongside yours but aren't yours.
    var includeInNetWorth: Bool = true
    /// Archived person. Hidden by default in People grid via "Show inactive"
    /// toggle. Does NOT change net-worth aggregation — that's `includeInNetWorth`.
    var isActive: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \Account.person)
    var accounts: [Account] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
    }
}
