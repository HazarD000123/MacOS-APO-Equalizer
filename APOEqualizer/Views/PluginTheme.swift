import SwiftUI

extension PluginKind {
    var accentColor: Color {
        switch self {
        case .toneShaper: return Color(red: 0.55, green: 0.85, blue: 0.55)
        case .haasWidener: return Color(red: 0.25, green: 0.65, blue: 0.95)
        case .stereoImager: return Color(red: 0.62, green: 0.42, blue: 0.95)
        case .punchCompressor: return Color(red: 0.95, green: 0.75, blue: 0.15)
        case .maximizer: return Color(red: 0.95, green: 0.32, blue: 0.28)
        }
    }
}
