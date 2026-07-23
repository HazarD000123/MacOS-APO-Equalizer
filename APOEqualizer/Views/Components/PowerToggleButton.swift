import SwiftUI

/// A circular power-icon toggle, styled after Equalizer APO's per-stage
/// enable buttons -- lit up (accent-colored) when the stage is active, dim
/// when it's bypassed.
struct PowerToggleButton: View {
    @Binding var isOn: Bool
    var tint: Color = .accentColor

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Image(systemName: "power")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isOn ? tint : Color.secondary.opacity(0.5))
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(isOn ? tint.opacity(0.15) : Color.secondary.opacity(0.08))
                )
                .overlay(
                    Circle().stroke(isOn ? tint.opacity(0.5) : Color.secondary.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(isOn ? "Enabled -- click to bypass" : "Bypassed -- click to enable")
    }
}
