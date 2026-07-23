import SwiftUI

struct ChainRowChrome<Content: View>: View {
    let number: Int
    @Binding var isEnabled: Bool
    var tint: Color = .accentColor
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 26)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)))

            PowerToggleButton(isOn: $isEnabled, tint: tint)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(isEnabled ? 1 : 0.45)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}

struct OpenPanelButton: View {
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 4) {
                Text(isExpanded ? "Close Panel" : "Open Panel")
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
