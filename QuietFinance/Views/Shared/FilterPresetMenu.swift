import SwiftUI

/// "Presets" menu for filterable screens (Breakdown, Trends): apply a saved
/// preset, save the current filters under a name, or delete presets.
struct FilterPresetMenu: View {
    let screen: String
    let currentPayload: () -> FilterPresets.Payload
    let onApply: (FilterPresets.Payload) -> Void

    @State private var namingPreset = false
    @State private var presetName = ""
    @State private var refresh = 0

    private var presets: [FilterPresets.Preset] {
        _ = refresh
        return FilterPresets.presets(forScreen: screen)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        Menu {
            if presets.isEmpty {
                Text("No saved presets")
            } else {
                ForEach(presets) { preset in
                    Button(preset.name) { onApply(preset.payload) }
                }
                Divider()
            }
            Button("Save current as preset…") {
                presetName = ""
                namingPreset = true
            }
            if !presets.isEmpty {
                Menu("Delete preset") {
                    ForEach(presets) { preset in
                        Button(preset.name, role: .destructive) {
                            FilterPresets.delete(id: preset.id)
                            refresh += 1
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 11, weight: .medium))
                Text("Presets")
                    .font(Typo.sans(11, weight: .medium))
            }
            .foregroundStyle(Color.lInk2)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
            .contentShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Apply or save filter presets")
        .alert("Save preset", isPresented: $namingPreset) {
            TextField("Preset name", text: $presetName)
            Button("Save") {
                let trimmed = presetName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                FilterPresets.save(FilterPresets.Preset(name: trimmed,
                                                        screen: screen,
                                                        payload: currentPayload()))
                refresh += 1
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saves the current grouping and filters for one-click reuse.")
        }
    }
}
