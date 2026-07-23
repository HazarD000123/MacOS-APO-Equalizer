import SwiftUI

/// A rotary knob control, used for the preamp gain. Drag vertically to
/// change the value (the standard "virtual knob" interaction, since a
/// literal circular drag is fussier to use with a mouse/trackpad).
/// Double-click resets to `resetValue`, or the midpoint of the range if
/// that's nil -- only correct as a default for symmetric ranges, so any
/// asymmetric range (like the preamp's -24...+50dB) should pass one
/// explicitly rather than silently resetting to some off-center value.
struct KnobView: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    let unit: String
    var tint: Color = .accentColor
    var diameter: CGFloat = 56
    var resetValue: Float?

    @State private var dragStartValue: Float?

    private var fraction: CGFloat {
        CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    private var indicatorAngle: Angle {
        .degrees(Double(fraction) * 270 - 135)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(135))

                Circle()
                    .trim(from: 0, to: 0.75 * fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(135))

                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                    .padding(9)

                Rectangle()
                    .fill(tint)
                    .frame(width: 2, height: diameter * 0.21)
                    .offset(y: -diameter * 0.23)
                    .rotationEffect(indicatorAngle)
            }
            .frame(width: diameter, height: diameter)
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

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(format: "%+.1f %@", value, unit))
                .font(.system(size: 10, design: .monospaced))
        }
    }
}
