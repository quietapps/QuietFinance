import Foundation
import SwiftData

@Model
final class Country {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var code: String   // "US", "IN"
    var name: String
    var flag: String
    var defaultCurrency: Currency
    var colorHex: String?

    @Relationship(deleteRule: .cascade, inverse: \Account.country)
    var accounts: [Account] = []

    init(code: String, name: String, flag: String, defaultCurrency: Currency) {
        self.id = UUID()
        self.code = code
        self.name = name
        self.flag = flag
        self.defaultCurrency = defaultCurrency
    }
}
