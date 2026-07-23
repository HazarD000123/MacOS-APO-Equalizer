import SwiftUI

struct LevelMeterView: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.15))
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: [.green, .yellow, .red], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(min(level * 1.3, 1.0)))
            }
        }
        .animation(.linear(duration: 0.05), value: level)
    }
}
