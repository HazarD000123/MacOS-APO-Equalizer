import AVFoundation
import AudioToolbox

final class ToneShaperKernel: EffectKernel {
    var bypassed = false
    var sampleRate: Double = 48000 { didSet { rebuildFilters() } }

    var lowGainDB: Float = 0 { didSet { rebuildFilters() } }
    var midGainDB: Float = 0 { didSet { rebuildFilters() } }
    var highGainDB: Float = 0 { didSet { rebuildFilters() } }
    var outputGainDB: Float = 0

    private let lowFrequency: Float = 150
    private let midFrequency: Float = 900
    private let highFrequency: Float = 5000

    private var low: [Biquad] = [Biquad(), Biquad()]
    private var mid: [Biquad] = [Biquad(), Biquad()]
    private var high: [Biquad] = [Biquad(), Biquad()]

    private func rebuildFilters() {
        let lowCoeffs = Biquad.lowShelf(sampleRate: sampleRate, frequency: lowFrequency, gainDB: lowGainDB)
        let midCoeffs = Biquad.peaking(sampleRate: sampleRate, frequency: midFrequency, gainDB: midGainDB, q: 0.7)
        let highCoeffs = Biquad.highShelf(sampleRate: sampleRate, frequency: highFrequency, gainDB: highGainDB)
        for ch in 0..<2 {
            low[ch].updateCoefficients(from: lowCoeffs)
            mid[ch].updateCoefficients(from: midCoeffs)
            high[ch].updateCoefficients(from: highCoeffs)
        }
    }

    func reset() {
        rebuildFilters()
        for ch in 0..<2 {
            low[ch].reset(); mid[ch].reset(); high[ch].reset()
        }
    }

    func process(buffers: [UnsafeMutablePointer<Float>], frameCount: Int) {
        let outGain = dBToLinear(outputGainDB)
        for ch in 0..<buffers.count where ch < 2 {
            let data = buffers[ch]
            for i in 0..<frameCount {
                var x = data[i]
                x = low[ch].process(x)
                x = mid[ch].process(x)
                x = high[ch].process(x)
                data[i] = x * outGain
            }
        }
    }
}

final class ToneShaperAudioUnit: BaseEffectAudioUnit {
    private let shaperKernel = ToneShaperKernel()

    override init(componentDescription: AudioComponentDescription,
                   options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        kernel = shaperKernel

        let lowParam = AUParameterTree.createParameter(
            withIdentifier: "low", name: "Low",
            address: 0, min: -15, max: 15, unit: .decibels, unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)
        let midParam = AUParameterTree.createParameter(
            withIdentifier: "mid", name: "Mid",
            address: 1, min: -15, max: 15, unit: .decibels, unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)
        let highParam = AUParameterTree.createParameter(
            withIdentifier: "high", name: "High",
            address: 2, min: -15, max: 15, unit: .decibels, unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)
        let outputParam = AUParameterTree.createParameter(
            withIdentifier: "outputGain", name: "Output",
            address: 3, min: -15, max: 15, unit: .decibels, unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)

        lowParam.value = 0
        midParam.value = 0
        highParam.value = 0
        outputParam.value = 0

        let tree = AUParameterTree.createTree(withChildren: [lowParam, midParam, highParam, outputParam])
        parameterTree = tree

        let k = shaperKernel
        tree.implementorValueObserver = { param, value in
            switch param.address {
            case 0: k.lowGainDB = value
            case 1: k.midGainDB = value
            case 2: k.highGainDB = value
            case 3: k.outputGainDB = value
            default: break
            }
        }
        tree.implementorValueProvider = { param in
            switch param.address {
            case 0: return k.lowGainDB
            case 1: return k.midGainDB
            case 2: return k.highGainDB
            case 3: return k.outputGainDB
            default: return 0
            }
        }
    }
}
