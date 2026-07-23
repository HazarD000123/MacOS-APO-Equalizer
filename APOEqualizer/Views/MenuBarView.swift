import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var engine: AudioEngineManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("APO Equalizer").font(.headline)
                Spacer()
                Circle()
                    .fill(engine.isRunning ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
            }

            LevelMeterView(level: engine.outputLevel)
                .frame(height: 6)

            Button {
                Task { await engine.toggleRunning() }
            } label: {
                Label(engine.isRunning ? "Stop" : "Start", systemImage: engine.isRunning ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!engine.isVirtualDeviceInstalled)

            Divider()

            HStack {
                Text("Preamp").font(.caption)
                Slider(
                    value: Binding(get: { engine.preampGainDB }, set: { engine.setPreampGain($0) }),
                    in: -24...50
                )
                Text(String(format: "%+.1f dB", engine.preampGainDB))
                    .font(.system(size: 10, design: .monospaced))
                    .frame(width: 55, alignment: .trailing)
            }

            Divider()

            Button("Open Main Window") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.plain)

            Button("Quit APO Equalizer") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 260)
    }
}
