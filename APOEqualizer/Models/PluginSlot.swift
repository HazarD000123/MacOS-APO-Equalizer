import Foundation

struct PluginSlot: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: PluginKind
    var bypass: Bool = false
    var parameters: [String: Float] = [:]

    init(id: UUID = UUID(), kind: PluginKind, bypass: Bool = false, parameters: [String: Float] = [:]) {
        self.id = id
        self.kind = kind
        self.bypass = bypass
        self.parameters = parameters
    }
}
