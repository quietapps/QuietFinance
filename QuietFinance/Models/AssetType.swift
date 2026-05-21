import Foundation
import SwiftData

@Model
final class AssetType {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var name: String
    var category: AssetCategory

    @Relationship(deleteRule: .nullify, inverse: \Account.assetType)
    var accounts: [Account] = []

    init(name: String, category: AssetCategory) {
        self.id = UUID()
        self.name = name
        self.category = category
    }
}
