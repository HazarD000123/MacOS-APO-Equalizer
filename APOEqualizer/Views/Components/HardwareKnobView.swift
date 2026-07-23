import SwiftUI

struct HardwareKnobView: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    let valueText: String
    var finish: Finish = .dark
    var tint: Color = .white
    var diameter: CGFloat = 52
    var resetValue: Float?

    @State private var dragStartValue: Float?

    enum Finish {
        case dark, light
    }

    private var fraction: CGFloat {
        CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    private var pointerAngle: Angle {
        .degrees(Double(fraction) * 270 - 135)
    }

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                ForEach(0..<21, id: \.self) { i in
                    let tickAngle = Double(i) / 20 * 270 - 135
                    let major = i % 5 == 0
                    Rectangle()
                        .fill(Color.white.opacity(major ? 0.55 : 0.22))
                        .frame(width: major ? 1.6 : 1, height: major ? 6 : 3.5)
                        .offset(y: -(diameter / 2 + 6))
                        .rotationEffect(.degrees(tickAngle))
                }

                Circle()
                    .fill(bodyGradient)
                    .frame(width: diameter, height: diameter)
                    .overlay(Circle().stroke(Color.black.opacity(0.55), lineWidth: 1))
                    .shadow(color: .black.opacity(0.5), radius: 2.5, y: 1.5)

                Circle()
                    .trim(from: 0.56, to: 0.93)
                    .stroke(Color.white.opacity(finish == .dark ? 0.10 : 0.35), lineWidth: diameter * 0.1)
                    .frame(width: diameter * 0.78, height: diameter * 0.78)
                    .rotationEffect(.degrees(-90))
                    .blendMode(.plusLighter)

                Rectangle()
                    .fill(tint)
                    .frame(width: 2, height: diameter * 0.3)
                    .offset(y: -diameter * 0.17)
                    .rotationEffect(pointerAngle)
                    .shadow(color: tint.opacity(0.7), radius: 2)
            }
            .frame(width: diameter + 20, height: diameter + 20)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { drag in
                        if dragStartValue == nil { dragStartValue = value }
                        let span = range.upperBound - range.lowerBound
                        let delta = Float(-drag.translation.height) / 120 * span
                        let newValue = (dragStartValue ?? value) + delta
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in dragStartValue = nil }
            )
            .onTapGesture(count: 2) {
                value = resetValue ?? (range.lowerBound + range.upperBound) / 2
            }

            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)

            Text(valueText)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.45)))
        }
    }

    private var bodyGradient: RadialGradient {
        switch finish {
        case .dark:
            return RadialGradient(colors: [Color(white: 0.26), Color(white: 0.06)], center: .init(x: 0.35, y: 0.3), startRadius: 1, endRadius: diameter * 0.75)
        case .light:
            return RadialGradient(colors: [Color(white: 0.88), Color(white: 0.55)], center: .init(x: 0.35, y: 0.3), startRadius: 1, endRadius: diameter * 0.75)
        }
    }
}
