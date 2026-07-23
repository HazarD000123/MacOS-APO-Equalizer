import AVFoundation
import AudioToolbox

/// Loudness maximizer. Unlike the Preamp, whose soft limiter keeps a boost
/// clean, this one distorts on purpose: upward expansion lifts the quiet parts,
/// drive pushes the level up, and the signal hard clips at 0 dBFS. The
/// flat-topped clipping is what reads as louder even though the peak can't go
/// past full scale.
///
/// Chain: expansion -> drive -> hard clip -> output trim.
final class MaximizerKernel: EffectKernel {
    var bypassed = false
    var sampleRate: Double = 48000

    /// Input gain in dB pushed into the clip. Higher is louder and dirtier.
    var driveDB: Float = 12 { didSet { driveLinear = dBToLinear(driveDB) } }
    /// Expansion amount, 0-100%, mapped to the power-curve exponent
    /// (0% = 1.0, off; 100% = 0.5, strongest lift).
    var loudness: Float = 0 { didSet { expGain = 1 - clamp(loudness / 100, 0, 1) * 0.5 } }
    /// Post-clip trim in dB, never above 0. Tames the level without losing density.
    var outputDB: Float = 0 { didSet { outputLinear = dBToLinear(outputDB) } }

    private var driveLinear: Float = dBToLinear(12)
    private var expGain: Float = 1
    private var outputLinear: Float = 1

    func reset() {}

    func process(buffers: [UnsafeMutablePointer<Float>], frameCount: Int) {
        let drive = driveLinear
        let exp = expGain
        let out = outputLinear
        let expand = exp != 1

        for ch in buffers {
            for i in 0..<frameCount {
                var x = ch[i]

                // Expansion is sign-preserving: x^exp with exp < 1 lifts quiet
                // samples much more than loud ones, so the average rises.
                if expand {
                    x = x >= 0 ? powf(x, exp) : -powf(-x, exp)
                }

                x *= drive
                if x > 1 { x = 1 } else if x < -1 { x = -1 }
                ch[i] = x * out
            }
        }
    }
}

final class MaximizerAudioUnit: BaseEffectAudioUnit {
    private let maximizerKernel = MaximizerKernel()

    override init(componentDescription: AudioComponentDescription,
                   options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        kernel = maximizerKernel

        let driveParam = AUParameterTree.createParameter(
            withIdentifier: "drive", name: "Drive",
            address: 0, min: 0, max: 48, unit: .decibels, unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)
        let loudnessParam = AUParameterTree.createParameter(
            withIdentifier: "loudness", name: "Loudness",
            address: 1, min: 0, max: 100, unit: .percent, unitName: "%",
            flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)
        let outputParam = AUParameterTree.createParameter(
            withIdentifier: "output", name: "Output",
            address: 2, min: -24, max: 0, unit: .decibels, unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)

        driveParam.value = 12
        loudnessParam.value = 0
        outputParam.value = 0

        let tree = AUParameterTree.createTree(withChildren: [driveParam, loudnessParam, outputParam])
        parameterTree = tree

        let k = maximizerKernel
        tree.implementorValueObserver = { param, value in
            switch param.address {
            case 0: k.driveDB = value
            case 1: k.loudness = value
            case 2: k.outputDB = value
            default: break
            }
        }
        tree.implementorValueProvider = { param in
            switch param.address {
            case 0: return k.driveDB
            case 1: return k.loudness
            case 2: return k.outputDB
            default: return 0
            }
        }
    }
}
