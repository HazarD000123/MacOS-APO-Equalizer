import SwiftUI

/// User-selectable app appearance, independent of (or matching) the system
/// setting. Persisted via the same `@AppStorage` key everywhere it's read
/// or written, so the app root and the picker control stay in sync without
/// needing a shared observable object for one value.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// A compact segmented control for switching appearance, meant for the
/// sidebar. Reads/writes the same `appearanceMode` key the app root uses to
/// drive `.preferredColorScheme`.
struct AppearancePickerView: View {
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue

    var body: some View {
        Picker("Appearance", selection: Binding(
            get: { AppearanceMode(rawValue: appearanceModeRaw) ?? .system },
            set: { appearanceModeRaw = $0.rawValue }
        )) {
            ForEach(AppearanceMode.allCases) { mode in
                Image(systemName: mode.icon)
                    .help(mode.label)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
