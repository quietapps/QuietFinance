import Foundation
import SwiftData

@Model
final class ReceivableValue {
    @Attribute(.unique) var id: UUID
    var snapshot: Snapshot?
    var receivable: Receivable?
    var nativeValue: Double
    var note: String

    init(snapshot: Snapshot, receivable: Receivable, nativeValue: Double, note: String = "") {
        self.id = UUID()
        self.snapshot = snapshot
        self.receivable = receivable
        self.nativeValue = nativeValue
        self.note = note
    }
}
