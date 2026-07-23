import AVFoundation
import AudioToolbox

/// Stereo Imager -- inspired by Wider. Real Wider doesn't just scale the
/// existing Mid/Side difference (that approach can't do anything to a
/// signal that's already mono -- scaling a zero side signal is still zero,
/// which is exactly the case for this app's mic-input pipeline). Instead it
/// runs an all-pass/comb filter network to *generate* new phase-decorrelated
/// content and blends it in, so it can widen a genuinely mono source, while
/// staying exactly mono-compatible: L=mid+side, R=mid-side always sums back
/// to 2*mid regardless of what `side` contains, by construction.
///
/// Two contributions are blended into `side`:
///  - the input's existing Mid/Side difference, scaled by width
///  - a decorrelated signal built by cascading Mid through staggered all-pass
///    filters (unity gain, phase only), faded in above 100% width so a mono
///    source still gets width
final class StereoImagerKernel: EffectKernel {
    var bypassed = false
    var sampleRate: Double = 48000 { didSet { rebuildFilters() } }

    var width: Float = 130              // 0-200 %, 100 = neutral
    var bassMonoFreq: Float = 120 { didSet { rebuildFilters() } }  // Hz, 0 disables
    var outputGainDB: Float = 0

    private var sideHighPass = Biquad()
    private var decorrelator: [Biquad] = []
    private let decorrelatorFrequencies: [Float] = [130, 430, 1200, 3400]

    private func rebuildFilters() {
        sideHighPass = Biquad.highPass(sampleRate: sampleRate, frequency: max(bassMonoFreq, 10), q: 0.707)
        decorrelator = decorrelatorFrequencies.map { Biquad.allPass(sampleRate: sampleRate, frequency: $0, q: 0.7) }
    }

    func reset() {
        rebuildFilters()
        sideHighPass.reset()
        for i in decorrelator.indices { decorrelator[i].reset() }
    }

    func process(buffers: [UnsafeMutablePointer<Float>], frameCount: Int) {
        guard buffers.count == 2 else { return }
        let l = buffers[0], r = buffers[1]
        let widthFactor = width / 100                 // 0...2
        let extraWidth = max(0, widthFactor - 1)       // 0...1, only kicks in above 100%
        let monoizeBass = bassMonoFreq > 15
        let outGain = dBToLinear(outputGainDB)

        for i in 0..<frameCount {
            let mid = (l[i] + r[i]) * 0.5
            let existingSide = (l[i] - r[i]) * 0.5

            var decorrelated = mid
            for stage in decorrelator.indices {
                decorrelated = decorrelator[stage].process(decorrelated)
            }

            var side = existingSide * widthFactor + decorrelated * extraWidth * 0.85
            if monoizeBass {
                side = sideHighPass.process(side)
            }

            l[i] = (mid + side) * outGain
            r[i] = (mid - side) * outGain
        }
    }
}

final class StereoImagerAudioUnit: BaseEffectAudioUnit {
    private let imagerKernel = StereoImagerKernel()

    override init(componentDescription: AudioComponentDescription,
                   options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        kernel = imagerKernel

        let widthParam = AUParameterTree.createParameter(
            withIdentifier: "width", name: "Width",
            address: 0, min: 0, max: 200, unit: .percent, unitName: "%",
            flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)
        let bassParam = AUParameterTree.createParameter(
            withIdentifier: "bassMono", name: "Bass Mono Below",
            address: 1, min: 0, max: 300, unit: .hertz, unitName: "Hz",
            flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)
        let gainParam = AUParameterTree.createParameter(
            withIdentifier: "outputGain", name: "Output Gain",
            address: 2, min: -12, max: 12, unit: .decibels, unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)

        widthParam.value = 130
        bassParam.value = 120
        gainParam.value = 0

        let tree = AUParameterTree.createTree(withChildren: [widthParam, bassParam, gainParam])
        parameterTree = tree

        let k = imagerKernel
        tree.implementorValueObserver = { param, value in
            switch param.address {
            case 0: k.width = value
            case 1: k.bassMonoFreq = value
            case 2: k.outputGainDB = value
            default: break
            }
        }
        tree.implementorValueProvider = { param in
            switch param.address {
            case 0: return k.width
            case 1: return k.bassMonoFreq
            case 2: return k.outputGainDB
            default: return 0
            }
        }
    }
}
