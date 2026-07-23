import SwiftUI

/// Gives each built-in plugin its own visual identity -- a distinct accent
/// color carried through its rack row, its knobs, and its signature mini
/// visualization -- the same way real plugins from different vendors don't
/// all look alike.
extension PluginKind {
    var accentColor: Color {
        switch self {
        case .toneShaper: return Color(red: 0.55, green: 0.85, blue: 0.55)      // sage green -- vintage hi-fi tone control
        case .haasWidener: return Color(red: 0.25, green: 0.65, blue: 0.95)    // cool cyan -- space/delay
        case .stereoImager: return Color(red: 0.62, green: 0.42, blue: 0.95)   // violet -- width/imaging
        case .punchCompressor: return Color(red: 0.95, green: 0.75, blue: 0.15) // amber -- energy/punch
        case .maximizer: return Color(red: 0.95, green: 0.32, blue: 0.28)       // hot red -- maximum loudness
        }
    }
}
