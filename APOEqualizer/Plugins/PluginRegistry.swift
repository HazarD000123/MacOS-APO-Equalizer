import AVFoundation
import AudioToolbox

/// The catalog of built-in effect plugins. Each one is a small, self
/// contained Audio Unit registered in-process (no extension bundle needed)
/// via `AUAudioUnit.registerSubclass`, then instantiated into the engine's
/// signal chain like any other AVAudioUnit node -- this is the same
/// mechanism a "real" third-party plugin uses, just shipped inside the app.
enum PluginKind: String, CaseIterable, Identifiable, Codable {
    case toneShaper
    case haasWidener
    case stereoImager
    case punchCompressor
    case maximizer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toneShaper: return "Tone Shaper"
        case .haasWidener: return "Haas Widener"
        case .stereoImager: return "Stereo Imager"
        case .punchCompressor: return "Punch Compressor"
        case .maximizer: return "Maximizer"
        }
    }

    var inspiredBy: String {
        switch self {
        case .toneShaper: return "Inspired by basiQ"
        case .haasWidener: return "Inspired by Quick Haas"
        case .stereoImager: return "Inspired by Wider"
        case .punchCompressor: return "Inspired by SweetDrums"
        case .maximizer: return "Inspired by LoudMax"
        }
    }

    var iconName: String {
        switch self {
        case .toneShaper: return "dial.medium.fill"
        case .haasWidener: return "arrow.left.and.right.circle"
        case .stereoImager: return "dot.radiowaves.left.and.right"
        case .punchCompressor: return "bolt.fill"
        case .maximizer: return "speaker.wave.3.fill"
        }
    }

    fileprivate var subtypeCode: OSType {
        switch self {
        case .toneShaper: return fourCC("tone")
        case .haasWidener: return fourCC("haas")
        case .stereoImager: return fourCC("wide")
        case .punchCompressor: return fourCC("pnch")
        case .maximizer: return fourCC("maxi")
        }
    }

    fileprivate var audioUnitClass: BaseEffectAudioUnit.Type {
        switch self {
        case .toneShaper: return ToneShaperAudioUnit.self
        case .haasWidener: return HaasWidenerAudioUnit.self
        case .stereoImager: return StereoImagerAudioUnit.self
        case .punchCompressor: return PunchCompressorAudioUnit.self
        case .maximizer: return MaximizerAudioUnit.self
        }
    }

    func componentDescription() -> AudioComponentDescription {
        AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: subtypeCode,
            componentManufacturer: PluginRegistry.manufacturerCode,
            componentFlags: 0, componentFlagsMask: 0
        )
    }
}

enum PluginRegistry {
    static let manufacturerCode = fourCC("Aeqz")
    private static var didRegister = false

    /// Must be called once before any plugin is instantiated (done at app launch).
    static func registerAll() {
        guard !didRegister else { return }
        didRegister = true

        for kind in PluginKind.allCases {
            AUAudioUnit.registerSubclass(
                kind.audioUnitClass,
                as: kind.componentDescription(),
                name: "APO Equalizer: \(kind.displayName)",
                version: 1
            )
        }
        AUAudioUnit.registerSubclass(
            PreampAudioUnit.self,
            as: PreampAudioUnit.componentDescription,
            name: "APO Equalizer: Preamp",
            version: 1
        )
    }

    static func instantiate(_ kind: PluginKind) async -> AVAudioUnit? {
        await withCheckedContinuation { continuation in
            AVAudioUnit.instantiate(with: kind.componentDescription(), options: []) { avAudioUnit, error in
                if let error {
                    print("APO Equalizer: failed to instantiate \(kind.displayName): \(error)")
                }
                continuation.resume(returning: avAudioUnit)
            }
        }
    }

    static func instantiatePreamp() async -> AVAudioUnit? {
        await withCheckedContinuation { continuation in
            AVAudioUnit.instantiate(with: PreampAudioUnit.componentDescription, options: []) { avAudioUnit, error in
                if let error {
                    print("APO Equalizer: failed to instantiate Preamp: \(error)")
                }
                continuation.resume(returning: avAudioUnit)
            }
        }
    }
}
