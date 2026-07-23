import Foundation

struct EQCurvePreset: Identifiable, Hashable {
    let id: String
    let name: String
    let gains: [Float]

    static let all: [EQCurvePreset] = [
        EQCurvePreset(id: "flat", name: "Flat", gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        EQCurvePreset(id: "bassBoost", name: "Bass Boost", gains: [7, 6, 5, 3, 1, 0, 0, 0, 0, 0]),
        EQCurvePreset(id: "trebleBoost", name: "Treble Boost", gains: [0, 0, 0, 0, 0, 0, 1, 3, 5, 6]),
        EQCurvePreset(id: "clear", name: "Clear", gains: [-1, -1, -1, -3, -2, 0, 3, 4, 2, 1]),
        EQCurvePreset(id: "warm", name: "Warm", gains: [3, 3, 2, 1, 0, 0, -1, -2, -2, -3]),
        EQCurvePreset(id: "loudness", name: "Loudness", gains: [6, 5, 3, 0, -2, -2, 0, 3, 5, 6]),
        EQCurvePreset(id: "podcast", name: "Podcast", gains: [-3, -2, -1, 0, 1, 2, 3, 3, 2, 2]),
        EQCurvePreset(id: "radio", name: "Radio", gains: [-10, -7, -3, 0, 0, 0, 0, -3, -7, -10]),
    ]
}
