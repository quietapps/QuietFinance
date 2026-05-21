import Foundation

enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
    /// "1.0 (12)" — short version + build
    static var versionString: String {
        "\(version) (\(build))"
    }
}
