import AVFoundation

enum EQFilterType: String, Codable, CaseIterable, Identifiable {
    case parametric, lowShelf, highShelf, lowPass, highPass, bandPass, resonantLowPass, resonantHighPass

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .parametric: return "Bell"
        case .lowShelf: return "Low Shelf"
        case .highShelf: return "High Shelf"
        case .lowPass: return "Low Pass"
        case .highPass: return "High Pass"
        case .bandPass: return "Band Pass"
        case .resonantLowPass: return "Resonant LP"
        case .resonantHighPass: return "Resonant HP"
        }
    }

    var avFilterType: AVAudioUnitEQFilterType {
        switch self {
        case .parametric: return .parametric
        case .lowShelf: return .lowShelf
        case .highShelf: return .highShelf
        case .lowPass: return .lowPass
        case .highPass: return .highPass
        case .bandPass: return .bandPass
        case .resonantLowPass: return .resonantLowPass
        case .resonantHighPass: return .resonantHighPass
        }
    }
}

struct EQBand: Identifiable, Codable, Hashable {
    var id: Int
    var frequency: Float
    var gain: Float = 0
    var bandwidth: Float = 1.0
    var filterType: EQFilterType = .parametric
    var bypass: Bool = false

    static func defaultTenBand() -> [EQBand] {
        let frequencies: [Float] = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        return frequencies.enumerated().map { index, freq in
            let type: EQFilterType
            if index == 0 {
                type = .lowShelf
            } else if index == frequencies.count - 1 {
                type = .highShelf
            } else {
                type = .parametric
            }
            return EQBand(id: index, frequency: freq, gain: 0, bandwidth: 1.0, filterType: type)
        }
    }
}
