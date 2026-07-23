import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case chain = "Chain"
    case devices = "Devices"
    case presets = "Presets"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chain: return "slider.horizontal.3"
        case .devices: return "mic.fill"
        case .presets: return "star.fill"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var engine: AudioEngineManager
    @State private var selection: AppSection? = .chain

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(AppSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom) {
                PowerControlView()
                    .padding(12)
            }
        } detail: {
            Group {
                switch selection ?? .chain {
                case .chain: ChainView()
                case .devices: DeviceSettingsView()
                case .presets: PresetsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("APO Equalizer")
        .onAppear { engine.refreshDevices() }
    }
}

struct PowerControlView: View {
    @EnvironmentObject var engine: AudioEngineManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(engine.isRunning ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text(engine.isRunning ? "Running" : "Stopped")
                    .font(.caption.weight(.semibold))
                Spacer()
            }

            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                LevelMeterView(level: engine.outputLevel)
                    .frame(height: 10)
            }

            Button {
                Task { await engine.toggleRunning() }
            } label: {
                Label(engine.isRunning ? "Stop" : "Start", systemImage: engine.isRunning ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(engine.isRunning ? .red : .accentColor)
            .disabled(!engine.isVirtualDeviceInstalled)

            Toggle(isOn: Binding(
                get: { engine.isMonitoring },
                set: { engine.setMonitorEnabled($0) }
            )) {
                Label("Monitor (hear it)", systemImage: "speaker.wave.2.fill")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .disabled(!engine.isRunning)
            .help("Plays the processed signal out your current speakers/headphones so you can hear it directly, in addition to sending it to BlackHole.")

            let message = engine.isVirtualDeviceInstalled ? engine.statusMessage : "BlackHole not installed -- see Devices"
            HStack(alignment: .top, spacing: 4) {
                if isWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                }
                Text(message)
                    .font(.caption2.weight(isWarning ? .semibold : .regular))
            }
            .foregroundStyle(isWarning ? Color.orange : Color.secondary)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Simple heuristic so failure messages actually stand out instead of
    /// reading the same as routine status text -- easy to miss otherwise.
    private var isWarning: Bool {
        guard engine.isVirtualDeviceInstalled else { return true }
        let msg = engine.statusMessage.lowercased()
        return ["couldn't", "failed", "denied", "no output", "no microphone", "isn't installed", "not found"].contains { msg.contains($0) }
    }
}
