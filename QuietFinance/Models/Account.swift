import Foundation
import SwiftData

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var person: Person?
    var country: Country?
    var assetType: AssetType?
    var nativeCurrency: Currency
    var institution: String
    var notes: String
    var isActive: Bool
    var createdAt: Date
    var groupName: String = ""
    /// Aggregate cost basis in this account's `nativeCurrency`. Used to compute
    /// unrealized gain (currentValue − costBasis). 0 = unset / not tracked.
    var costBasis: Double = 0
    /// User-defined ordering. Lower = earlier in lists. New accounts inherit
    /// (max + 1). Default 0 lets old data fall to top until backfilled.
    var sortIndex: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \AssetValue.account)
    var values: [AssetValue] = []

    init(name: String,
         person: Person,
         country: Country,
         assetType: AssetType,
         nativeCurrency: Currency,
         institution: String = "",
         notes: String = "",
         isActive: Bool = true) {
        self.id = UUID()
        self.name = name
        self.person = person
        self.country = country
        self.assetType = assetType
        self.nativeCurrency = nativeCurrency
        self.institution = institution
        self.notes = notes
        self.isActive = isActive
        self.createdAt = .now
    }
}
