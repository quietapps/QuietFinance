import SwiftUI
import AppKit
import Combine

struct ColumnSpec: Identifiable, Hashable {
    let id: String
    let title: String
    let minWidth: CGFloat
    let defaultWidth: CGFloat
    var alignment: TextAlignment = .leading
    var flex: Bool = false
    var resizable: Bool = true
    /// When true, header is clickable and cycles ASC → DESC → unsorted. The
    /// owning view supplies the actual comparator via `ColumnSizer.sorted(_:comparators:)`.
    var sortable: Bool = true
}

final class ColumnSizer: ObservableObject {
    let tableID: String
    let specs: [ColumnSpec]
    @Published private(set) var widths: [String: CGFloat] = [:]
    @Published private(set) var titleOverrides: [String: String] = [:]

    /// Active sort column. `nil` means use the view's default ordering (whatever
    /// the underlying `@Query` or computed list yields).
    @Published private(set) var sortColumnID: String?
    @Published private(set) var sortAscending: Bool = true

    init(tableID: String, specs: [ColumnSpec]) {
        self.tableID = tableID
        self.specs = specs
        for s in specs {
            let stored = UserDefaults.standard.double(forKey: Self.key(tableID, s.id))
            widths[s.id] = stored > 0 ? max(stored, s.minWidth) : s.defaultWidth
        }
        // Restore persisted sort state.
        if let raw = UserDefaults.standard.string(forKey: Self.sortKey(tableID)) {
            // Format: "<colID>|asc" or "<colID>|desc". Empty / missing = no sort.
            let parts = raw.split(separator: "|", maxSplits: 1).map(String.init)
            if parts.count == 2,
               specs.contains(where: { $0.id == parts[0] && $0.sortable }) {
                sortColumnID = parts[0]
                sortAscending = parts[1] == "asc"
            }
        }
    }

    func setTitle(_ id: String, _ title: String?) {
        if let title { titleOverrides[id] = title } else { titleOverrides.removeValue(forKey: id) }
    }

    func title(for id: String) -> String {
        titleOverrides[id] ?? specs.first(where: { $0.id == id })?.title ?? id
    }

    private static func key(_ tableID: String, _ colID: String) -> String {
        "col.\(tableID).\(colID)"
    }

    private static func sortKey(_ tableID: String) -> String {
        "sort.\(tableID)"
    }

    func width(_ id: String) -> CGFloat {
        widths[id] ?? specs.first(where: { $0.id == id })?.defaultWidth ?? 100
    }

    func set(_ id: String, _ width: CGFloat) {
        guard let spec = specs.first(where: { $0.id == id }) else { return }
        let clamped = max(spec.minWidth, width)
        widths[id] = clamped
        UserDefaults.standard.set(clamped, forKey: Self.key(tableID, id))
    }

    func reset() {
        for s in specs {
            widths[s.id] = s.defaultWidth
            UserDefaults.standard.removeObject(forKey: Self.key(tableID, s.id))
        }
    }

    // MARK: - Sort

    /// Cycle: not-active → ASC, ASC → DESC, DESC → unsorted (default).
    func cycleSort(_ id: String) {
        if sortColumnID == id {
            if sortAscending {
                sortAscending = false
            } else {
                sortColumnID = nil
                sortAscending = true
            }
        } else {
            sortColumnID = id
            sortAscending = true
        }
        persistSort()
    }

    private func persistSort() {
        let key = Self.sortKey(tableID)
        if let id = sortColumnID {
            UserDefaults.standard.set("\(id)|\(sortAscending ? "asc" : "desc")", forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// Apply the active sort to `items` using a comparator keyed by column id.
    /// The comparator returns true when `lhs` should come before `rhs` in
    /// **ascending** order. DESC simply reverses the result. If no sort is
    /// active or no comparator is provided for the active column, returns the
    /// input unchanged.
    func sorted<T>(_ items: [T], comparators: [String: (T, T) -> Bool]) -> [T] {
        guard let id = sortColumnID, let cmp = comparators[id] else { return items }
        let asc = items.sorted(by: cmp)
        return sortAscending ? asc : asc.reversed()
    }
}

private struct ColAlignment {
    static func swiftUI(_ a: TextAlignment) -> Alignment {
        switch a {
        case .leading:  return .leading
        case .center:   return .center
        case .trailing: return .trailing
        }
    }
}

struct ResizableHeader: View {
    @ObservedObject var sizer: ColumnSizer

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(sizer.specs.enumerated()), id: \.element.id) { idx, spec in
                ZStack(alignment: .trailing) {
                    headerLabel(spec)
                    if spec.resizable && idx < sizer.specs.count - 1 {
                        ResizeHandle(sizer: sizer, colID: spec.id)
                    }
                }
                .applyWidth(spec: spec, sizer: sizer)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.lSunken)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.lLine), alignment: .bottom)
    }

    @ViewBuilder
    private func headerLabel(_ spec: ColumnSpec) -> some View {
        let isSorted = sizer.sortColumnID == spec.id
        let titleText = sizer.title(for: spec.id)
        if spec.sortable && !titleText.isEmpty {
            Button {
                sizer.cycleSort(spec.id)
            } label: {
                HStack(spacing: 4) {
                    if spec.alignment == .trailing { Spacer(minLength: 0) }
                    Text(titleText)
                        .font(Typo.eyebrow).tracking(1.2)
                        .foregroundStyle(isSorted ? Color.lInk : Color.lInk3)
                        .lineLimit(1)
                    if isSorted {
                        Image(systemName: sizer.sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(Color.lInk)
                    }
                    if spec.alignment != .trailing { Spacer(minLength: 0) }
                }
                .frame(maxWidth: .infinity,
                       alignment: ColAlignment.swiftUI(spec.alignment))
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
            .help("Sort by \(titleText)")
        } else {
            Text(titleText)
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(Color.lInk3)
                .frame(maxWidth: .infinity,
                       alignment: ColAlignment.swiftUI(spec.alignment))
                .lineLimit(1)
                .padding(.horizontal, 8)
        }
    }
}

struct ResizableCell<Content: View>: View {
    @ObservedObject var sizer: ColumnSizer
    let colID: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        guard let spec = sizer.specs.first(where: { $0.id == colID }) else {
            return AnyView(content())
        }
        return AnyView(
            content()
                .frame(maxWidth: .infinity,
                       alignment: ColAlignment.swiftUI(spec.alignment))
                .padding(.horizontal, 8)
                .applyWidth(spec: spec, sizer: sizer)
        )
    }
}

private struct ResizeHandle: View {
    @ObservedObject var sizer: ColumnSizer
    let colID: String
    @State private var start: CGFloat?

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 10)
            .contentShape(Rectangle())
            .overlay(alignment: .center) {
                Rectangle()
                    .fill(Color.lLine.opacity(0.7))
                    .frame(width: 1)
            }
            .onHover { h in
                if h { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { g in
                        if start == nil { start = sizer.width(colID) }
                        sizer.set(colID, (start ?? 0) + g.translation.width)
                    }
                    .onEnded { _ in start = nil }
            )
    }
}

private extension View {
    @ViewBuilder
    func applyWidth(spec: ColumnSpec, sizer: ColumnSizer) -> some View {
        if spec.flex {
            self.frame(minWidth: spec.minWidth, maxWidth: .infinity)
        } else {
            self.frame(width: sizer.width(spec.id))
        }
    }
}
