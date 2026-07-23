import SwiftUI

struct PluginChrome<Content: View>: View {
    let title: String
    let subtitle: String
    let tint: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .tracking(2.5)
                    .foregroundStyle(.white)
                Text(subtitle.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(tint)
            }
            content()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(chassis)
        .overlay(alignment: .topLeading) { screw.padding(9) }
        .overlay(alignment: .topTrailing) { screw.padding(9) }
        .overlay(alignment: .bottomLeading) { screw.padding(9) }
        .overlay(alignment: .bottomTrailing) { screw.padding(9) }
    }

    private var chassis: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(LinearGradient(colors: [Color(white: 0.17), Color(white: 0.07)], startPoint: .top, endPoint: .bottom))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.02)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }

    private var screw: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(white: 0.5), Color(white: 0.15)], center: .topLeading, startRadius: 0, endRadius: 5))
            .frame(width: 6, height: 6)
            .overlay(Circle().stroke(.black.opacity(0.4), lineWidth: 0.5))
    }
}

struct PillSelector: View {
    let options: [String]
    @Binding var selection: Int
    var tint: Color = .white

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options.indices, id: \.self) { i in
                let isSelected = i == selection
                Button {
                    selection = i
                } label: {
                    Text(options[i].uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.65))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minWidth: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? tint : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
