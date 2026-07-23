import AVFoundation
import AudioToolbox

final class HaasWidenerKernel: EffectKernel {
    var bypassed = false
    var sampleRate: Double = 48000 { didSet { rebuildDelayLines() } }

    var pan: Float = 15
    var routingMode: Float = 0

    private var delayLineL = DelayLine(maxDelaySamples: 4096)
    private var delayLineR = DelayLine(maxDelaySamples: 4096)
    private var cachedCapacity = 4096

    private func rebuildDelayLines() {
        let capacity = max(64, Int(sampleRate * 0.05))
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
            case 2:
                sourceL = l[i]; sourceR = l[i]
            case 3:
                sourceL = r[i]; sourceR = r[i]
            case 1:
                sourceL = l[i]; sourceR = r[i]
            default:
                let m = (l[i] + r[i]) * 0.5
                sourceL = m; sourceR = m
            }

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
