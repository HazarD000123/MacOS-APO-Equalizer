import AVFoundation
import AudioToolbox

final class MaximizerKernel: EffectKernel {
    var bypassed = false
    var sampleRate: Double = 48000

    var driveDB: Float = 12 { didSet { driveLinear = dBToLinear(driveDB) } }
    var loudness: Float = 0 { didSet { expGain = 1 - clamp(loudness / 100, 0, 1) * 0.5 } }
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
