import SwiftUI

struct VerticalSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>

    private func fraction(for value: Float) -> CGFloat {
        CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let width = geo.size.width
            let f = min(max(fraction(for: value), 0), 1)
            let thumbY = height * (1 - f)
            let fillHeight = max(2, height - thumbY)

            ZStack {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 4, height: height)

                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 4, height: fillHeight)
                    .position(x: width / 2, y: thumbY + fillHeight / 2)

                Circle()
                    .fill(Color(nsColor: .textBackgroundColor))
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                    .position(x: width / 2, y: thumbY)
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let clampedY = min(max(0, drag.location.y), height)
                        let newFraction = 1 - Double(clampedY / height)
                        let newValue = Float(newFraction) * (range.upperBound - range.lowerBound) + range.lowerBound
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }
            )
            .onTapGesture(count: 2) {
                value = 0
            }
        }
    }
}
