import Foundation

/// A plugin instance in the rack. This is pure data (Codable, for presets);
/// the live `AVAudioUnit` it drives is kept separately by
/// `AudioEngineManager`, keyed by `id`.
struct PluginSlot: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: PluginKind
    var bypass: Bool = false
    /// AUParameter identifier -> value, kept in sync with the live AU so
    /// presets can restore exact parameter values.
    var parameters: [String: Float] = [:]

    init(id: UUID = UUID(), kind: PluginKind, bypass: Bool = false, parameters: [String: Float] = [:]) {
        self.id = id
        self.kind = kind
        self.bypass = bypass
        self.parameters = parameters
    }
}
