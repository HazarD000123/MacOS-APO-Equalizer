import SwiftUI

struct DeviceSettingsView: View {
    @EnvironmentObject var engine: AudioEngineManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Devices & Setup")
                    .font(.title3.bold())

                GroupBox("Virtual Microphone Driver") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: engine.isVirtualDeviceInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(engine.isVirtualDeviceInstalled ? .green : .orange)
                            Text(engine.isVirtualDeviceInstalled ? "BlackHole is installed" : "BlackHole is not installed")
                                .font(.body.weight(.medium))
                        }
                        Text("APO Equalizer needs BlackHole, a free virtual audio driver, to publish the processed voice as a selectable \"microphone\" that other apps can use.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !engine.isVirtualDeviceInstalled {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Install with Homebrew, then restart this app:")
                                    .font(.caption.weight(.semibold))
                                Text("brew install blackhole-2ch")
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 4).fill(.quaternary))
                                Text("Or download the installer from existentialaudio's BlackHole project page.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Button("Check Again") { engine.refreshDevices() }
                                .buttonStyle(.bordered)
                        }
                    }
                    .padding(8)
                }

                GroupBox("Microphone") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your voice is captured from this device before processing.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("Microphone", selection: Binding(
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

                        Button("Refresh Devices") { engine.refreshDevices() }
                            .buttonStyle(.bordered)
                    }
                    .padding(8)
                }

                GroupBox("How This Works") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pressing Start reads your microphone, runs it through the preamp, EQ, and any plugins you've added, and writes the result to \"BlackHole 2ch\", a virtual audio device.")
                        Text("To actually hear or send the processed voice, open the app you want to use it in (Zoom, Discord, OBS, FaceTime, QuickTime, etc.) and choose \"BlackHole 2ch\" as its microphone/input device in that app's audio settings. This app never changes your Mac's system-wide microphone or output -- only the apps you explicitly point at BlackHole will hear the processed audio.")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
        }
    }
}
