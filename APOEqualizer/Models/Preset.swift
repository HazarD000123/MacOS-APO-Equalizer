import Foundation

struct Preset: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var preampGainDB: Float
    var preampLimiterEnabled: Bool
    var eqEnabled: Bool
    var eqBands: [EQBand]
    var pluginSlots: [PluginSlot]
    var dateModified: Date = Date()

    static func flat(named name: String = "Flat") -> Preset {
        Preset(name: name,
               preampGainDB: 0,
               preampLimiterEnabled: true,
               eqEnabled: true,
               eqBands: EQBand.defaultTenBand(),
               pluginSlots: [])
    }
}

/// Reads/writes presets as JSON files under Application Support. No
/// database needed -- there will only ever be a handful of these.
final class PresetStore {
    static let shared = PresetStore()

    private let directory: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = appSupport.appendingPathComponent("APOEqualizer/Presets", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(for preset: Preset) -> URL {
        directory.appendingPathComponent("\(preset.id.uuidString).json")
    }

    func loadAll() -> [Preset] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> Preset? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(Preset.self, from: data)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    @discardableResult
    func save(_ preset: Preset) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(preset) else { return false }
        return (try? data.write(to: fileURL(for: preset), options: .atomic)) != nil
    }

    @discardableResult
    func delete(_ preset: Preset) -> Bool {
        (try? FileManager.default.removeItem(at: fileURL(for: preset))) != nil
    }
}
