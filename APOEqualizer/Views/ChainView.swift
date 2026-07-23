import SwiftUI

struct ChainView: View {
    @EnvironmentObject var engine: AudioEngineManager
    @State private var eqExpanded = true
    @State private var expandedPluginID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                toolbar
                Divider().padding(.vertical, 2)

                preampRow
                eqRow

                ForEach(Array(engine.pluginSlots.enumerated()), id: \.element.id) { index, slot in
                    pluginRow(slot: slot, number: index + 3)
                }

                addPluginRow
            }
            .padding(20)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.fill")
                .foregroundStyle(.secondary)
            Text("Device:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("", selection: Binding(
                get: { engine.selectedInputDeviceUID ?? "" },
                set: { uid in
                    if let device = engine.availableInputDevices.first(where: { $0.uid == uid }) {
                        Task { await engine.setInputDevice(device) }
                    }
                }
            )) {
                ForEach(engine.availableInputDevices) { device in
                    Text(device.name).tag(device.uid)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 240)

            Spacer()

            AppearancePickerView()
        }
    }

    private var preampRow: some View {
        ChainRowChrome(number: 1, isEnabled: Binding(
            get: { !engine.preampBypassed },
            set: { engine.setPreampBypassed(!$0) }
        )) {
            HStack(alignment: .top, spacing: 20) {
                KnobView(
                    value: Binding(get: { engine.preampGainDB }, set: { engine.setPreampGain($0) }),
                    range: -24...50, label: "Gain", unit: "dB", diameter: 44, resetValue: 0
                )
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preamplification").font(.body.weight(.semibold))
                    Slider(
                        value: Binding(get: { engine.preampGainDB }, set: { engine.setPreampGain($0) }),
                        in: -24...50, step: 0.5
                    )
                    Toggle("Safety limiter (soft-clips instead of distorting when boosted)", isOn: Binding(
                        get: { engine.preampLimiterEnabled },
                        set: { engine.setPreampLimiterEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .font(.caption)
                }
            }
        }
    }

    private var eqRow: some View {
        ChainRowChrome(number: 2, isEnabled: Binding(
            get: { engine.eqEnabled },
            set: { engine.setEQEnabled($0) }
        )) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("10-Band Equalizer").font(.body.weight(.semibold))
                    Spacer()
                    Menu("Presets") {
                        ForEach(EQCurvePreset.all) { curve in
                            Button(curve.name) { engine.applyEQCurve(curve) }
                        }
                    }
                    .menuStyle(.borderedButton)
                    .controlSize(.small)
                    .fixedSize()
                    Button("Reset") { engine.resetEQ() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    OpenPanelButton(isExpanded: $eqExpanded)
                }
                if eqExpanded {
                    HStack(alignment: .bottom, spacing: 14) {
                        ForEach(engine.eqBands) { band in
                            EQBandFader(band: band)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func pluginRow(slot: PluginSlot, number: Int) -> some View {
        let index = engine.pluginSlots.firstIndex(where: { $0.id == slot.id })

        return ChainRowChrome(number: number, isEnabled: Binding(
            get: { !slot.bypass },
            set: { engine.setPluginBypass(slot.id, bypass: !$0) }
        ), tint: slot.kind.accentColor) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: slot.kind.iconName)
                        .foregroundStyle(slot.kind.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(slot.kind.displayName).font(.body.weight(.semibold))
                        Text(slot.kind.inspiredBy).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()

                    VStack(spacing: 0) {
                        Button { moveUp(slot) } label: { Image(systemName: "chevron.up") }
                            .disabled(index == nil || index == 0)
                        Button { moveDown(slot) } label: { Image(systemName: "chevron.down") }
                            .disabled(index == nil || index == engine.pluginSlots.count - 1)
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    Button {
                        engine.removePlugin(slot.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    OpenPanelButton(isExpanded: Binding(
                        get: { expandedPluginID == slot.id },
                        set: { expandedPluginID = $0 ? slot.id : nil }
                    ))
                }
                if expandedPluginID == slot.id {
                    PluginPanelView(slot: slot)
                }
            }
        }
    }

    private func moveUp(_ slot: PluginSlot) {
        guard let idx = engine.pluginSlots.firstIndex(where: { $0.id == slot.id }), idx > 0 else { return }
        engine.movePlugins(fromOffsets: IndexSet(integer: idx), toOffset: idx - 1)
    }

    private func moveDown(_ slot: PluginSlot) {
        guard let idx = engine.pluginSlots.firstIndex(where: { $0.id == slot.id }), idx < engine.pluginSlots.count - 1 else { return }
        engine.movePlugins(fromOffsets: IndexSet(integer: idx), toOffset: idx + 2)
    }

    private var addPluginRow: some View {
        Menu {
            ForEach(PluginKind.allCases) { kind in
                Button {
                    Task { await engine.addPlugin(kind) }
                } label: {
                    Label(kind.displayName, systemImage: kind.iconName)
                }
            }
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Plugin to Chain")
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(14)
        }
        .menuStyle(.borderlessButton)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
    }
}

private struct EQBandFader: View {
    @EnvironmentObject var engine: AudioEngineManager
    let band: EQBand

    var body: some View {
        VStack(spacing: 6) {
            Text(String(format: "%+.1f", band.gain))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
            VerticalSlider(
                value: Binding(
                    get: { band.gain },
                    set: { newValue in
                        var updated = band
                        updated.gain = newValue
                        engine.updateEQBand(updated)
                    }
                ),
                range: -24...24
            )
            .frame(width: 24, height: 130)
            Text(frequencyLabel(band.frequency))
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    private func frequencyLabel(_ freq: Float) -> String {
        freq >= 1000 ? String(format: "%.0fk", freq / 1000) : String(format: "%.0f", freq)
    }
}
