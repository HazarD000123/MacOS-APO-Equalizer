import AVFoundation
import AudioToolbox

final class PreampKernel: EffectKernel {
    var bypassed = false
    var sampleRate: Double = 48000

    var gainDB: Float = 0 { didSet { gainLinear = dBToLinear(gainDB) } }
    var limiterEnabled: Bool = true

    private var gainLinear: Float = 1.0

    func reset() {}

    func process(buffers: [UnsafeMutablePointer<Float>], frameCount: Int) {
        let g = gainLinear
        if limiterEnabled {
            for ch in buffers {
                for i in 0..<frameCount {
                    ch[i] = softClip(ch[i] * g)
                }
            }
        } else {
            for ch in buffers {
                for i in 0..<frameCount {
                    ch[i] = ch[i] * g
                }
            }
        }
    }
}

final class PreampAudioUnit: BaseEffectAudioUnit {
    static let componentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: fourCC("pAmp"),
        componentManufacturer: PluginRegistry.manufacturerCode,
        componentFlags: 0, componentFlagsMask: 0
    )

    private let preampKernel = PreampKernel()

    override init(componentDescription: AudioComponentDescription,
                   options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        kernel = preampKernel

        let gainParam = AUParameterTree.createParameter(
            withIdentifier: "gain", name: "Preamp Gain",
            address: 0, min: -24, max: 50, unit: .decibels, unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)
        let limiterParam = AUParameterTree.createParameter(
            withIdentifier: "limiter", name: "Safety Limiter",
            address: 1, min: 0, max: 1, unit: .boolean, unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)
        gainParam.value = 0
        limiterParam.value = 1

        let tree = AUParameterTree.createTree(withChildren: [gainParam, limiterParam])
        parameterTree = tree

        let k = preampKernel
        tree.implementorValueObserver = { param, value in
            switch param.address {
            case 0: k.gainDB = value
            case 1: k.limiterEnabled = value >= 0.5
            default: break
            }
        }
        tree.implementorValueProvider = { param in
            switch param.address {
            case 0: return k.gainDB
            case 1: return k.limiterEnabled ? 1 : 0
            default: return 0
            }
        }
    }
}
