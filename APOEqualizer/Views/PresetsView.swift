import SwiftUI

struct PresetsView: View {
    @EnvironmentObject var engine: AudioEngineManager
    @State private var presets: [Preset] = []
    @State private var newPresetName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Presets")
                .font(.title3.bold())
            Text("Save the current preamp, EQ, and plugin rack as a named preset you can recall later.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("Preset name", text: $newPresetName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(savePreset)
                Button("Save Current") { savePreset() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if presets.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "star.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No Presets Saved")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                List {
                    ForEach(presets) { preset in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name).font(.body.weight(.medium))
                                Text("Preamp \(String(format: "%+.1f", preset.preampGainDB)) dB \u{2022} \(preset.pluginSlots.count) plugin(s)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Load") {
                                Task { await engine.applyPreset(preset) }
                            }
                            .buttonStyle(.bordered)
                            Button(role: .destructive) {
                                PresetStore.shared.delete(preset)
                                reload()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { reload() }
    }

    private func savePreset() {
        let name = newPresetName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let preset = engine.currentPreset(named: name)
        PresetStore.shared.save(preset)
        newPresetName = ""
        reload()
    }

    private func reload() {
        presets = PresetStore.shared.loadAll()
    }
}
