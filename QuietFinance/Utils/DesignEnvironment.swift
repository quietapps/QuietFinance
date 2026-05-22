import SwiftUI

private struct UseModernDesignKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var useModernDesign: Bool {
        get { self[UseModernDesignKey.self] }
        set { self[UseModernDesignKey.self] = newValue }
    }
}
