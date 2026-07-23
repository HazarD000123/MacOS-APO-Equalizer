import AVFoundation
import AudioToolbox

/// Haas widener with a single bipolar delay knob: negative pans left,
/// positive pans right, center is a no-op. Four routing modes pick the source
/// before panning -- Mono (sum L+R), Stereo (keep L/R), Dual L, Dual R. Mono
/// is the default here since the input is a single microphone.
final class HaasWidenerKernel: EffectKernel {
    var bypassed = false
    var sampleRate: Double = 48000 { didSet { rebuildDelayLines() } }

    var pan: Float = 15          // -40...40 ms; negative = pans left, positive = pans right
    var routingMode: Float = 0   // 0=Mono, 1=Stereo, 2=Dual L, 3=Dual R

    private var delayLineL = DelayLine(maxDelaySamples: 4096)
    private var delayLineR = DelayLine(maxDelaySamples: 4096)
    private var cachedCapacity = 4096

    private func rebuildDelayLines() {
        let capacity = max(64, Int(sampleRate * 0.05)) // 50ms of headroom
        guard capacity != cachedCapacity else { return }
        delayLineL = DelayLine(maxDelaySamples: capacity)
        delayLineR = DelayLine(maxDelaySamples: capacity)
        cachedCapacity = capacity
    }

    func reset() {
        rebuildDelayLines()
        delayLineL.reset()
        delayLineR.reset()
    }

    func process(buffers: [UnsafeMutablePointer<Float>], frameCount: Int) {
        guard buffers.count == 2 else { return }
        let l = buffers[0], r = buffers[1]
        let delaySamples = Int((abs(pan) / 1000) * Float(sampleRate))
        let mode = Int(routingMode.rounded())

        for i in 0..<frameCount {
            let sourceL: Float
            let sourceR: Float
            switch mode {
            case 2: // Dual L -- both sides sourced from the left channel
                sourceL = l[i]; sourceR = l[i]
            case 3: // Dual R -- both sides sourced from the right channel
                sourceL = r[i]; sourceR = r[i]
            case 1: // Stereo -- preserve the existing L/R image
                sourceL = l[i]; sourceR = r[i]
            default: // Mono -- sum to a single center source first
                let m = (l[i] + r[i]) * 0.5
                sourceL = m; sourceR = m
            }

            // Delaying a channel makes the *other* channel's sound arrive
            // first, so the ear perceives the source from that side
            // (precedence effect): pan > 0 (right) delays the left channel.
            l[i] = delayLineL.process(sourceL, delaySamples: pan > 0 ? delaySamples : 0)
            r[i] = delayLineR.process(sourceR, delaySamples: pan < 0 ? delaySamples : 0)
        }
    }
}

final class HaasWidenerAudioUnit: BaseEffectAudioUnit {
    private let haasKernel = HaasWidenerKernel()

    override init(componentDescription: AudioComponentDescription,
                   options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        kernel = haasKernel

        let panParam = AUParameterTree.createParameter(
            withIdentifier: "pan", name: "Delay Pan",
            address: 0, min: -40, max: 40, unit: .milliseconds, unitName: "ms",
            flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)
        let routingParam = AUParameterTree.createParameter(
            withIdentifier: "routing", name: "Input Routing",
            address: 1, min: 0, max: 3, unit: .indexed, unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: ["Mono", "Stereo", "Dual L", "Dual R"], dependentParameters: nil)

        panParam.value = 15
        routingParam.value = 0

        let tree = AUParameterTree.createTree(withChildren: [panParam, routingParam])
        parameterTree = tree

        let k = haasKernel
        tree.implementorValueObserver = { param, value in
            switch param.address {
            case 0: k.pan = value
            case 1: k.routingMode = value
            default: break
            }
        }
        tree.implementorValueProvider = { param in
            switch param.address {
            case 0: return k.pan
            case 1: return k.routingMode
            default: return 0
            }
        }
    }
}
