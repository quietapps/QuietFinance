import Foundation

/// Named filter presets + last-used filter state for Breakdown and Trends,
/// JSON-encoded into AppStorage/UserDefaults.
enum FilterPresets {
    struct FilterDef: Codable, Equatable {
        let key: String          // GroupKey raw value
        let label: String
        let matchValue: String
    }

    struct Payload: Codable, Equatable {
        var groupBy: String? = nil      // Breakdown grouping
        var filters: [FilterDef] = []
        var range: String? = nil        // Trends range raw value
        var seriesMode: String? = nil   // Trends series raw value
    }

    struct Preset: Codable, Identifiable, Equatable {
        var id: UUID = UUID()
        var name: String
        var screen: String              // "breakdown" | "trends"
        var payload: Payload
    }

    private static let presetsKey = "filterPresets"
    static func lastUsedKey(forScreen screen: String) -> String { "lastFilters.\(screen)" }

    // MARK: presets

    static func all() -> [Preset] {
        guard let data = UserDefaults.standard.string(forKey: presetsKey)?.data(using: .utf8),
              let list = try? JSONDecoder().decode([Preset].self, from: data) else { return [] }
        return list
    }

    static func presets(forScreen screen: String) -> [Preset] {
        all().filter { $0.screen == screen }
    }

    static func save(_ preset: Preset) {
        var list = all()
        list.removeAll { $0.id == preset.id || ($0.screen == preset.screen && $0.name == preset.name) }
        list.append(preset)
        persist(list)
    }

    static func delete(id: UUID) {
        persist(all().filter { $0.id != id })
    }

    private static func persist(_ list: [Preset]) {
        guard let data = try? JSONEncoder().encode(list),
              let str = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(str, forKey: presetsKey)
    }

    // MARK: last-used state

    static func saveLastUsed(_ payload: Payload, forScreen screen: String) {
        guard let data = try? JSONEncoder().encode(payload),
              let str = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(str, forKey: lastUsedKey(forScreen: screen))
    }

    static func lastUsed(forScreen screen: String) -> Payload? {
        guard let data = UserDefaults.standard.string(forKey: lastUsedKey(forScreen: screen))?.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return nil }
        return payload
    }

    // MARK: Filter conversion

    static func defs(from filters: [Filter]) -> [FilterDef] {
        filters.map { FilterDef(key: $0.key.rawValue, label: $0.label, matchValue: $0.matchValue) }
    }

    static func filters(from defs: [FilterDef]) -> [Filter] {
        defs.compactMap { def in
            GroupKey(rawValue: def.key).map { Filter(key: $0, label: def.label, matchValue: def.matchValue) }
        }
    }
}
