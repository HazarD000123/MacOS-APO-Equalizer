import AVFoundation
import AudioToolbox

enum PunchCompressorMapping {
    static func thresholdDB(forProcess process: Float) -> Float {
        -6 - clamp(process / 100, 0, 1) * 34
    }
    static func ratio(forProcess process: Float) -> Float {
        1 + clamp(process / 100, 0, 1) * 7
    }
}

final class PunchCompressorKernel: EffectKernel {
    var bypassed = false
    var sampleRate: Double = 48000 { didSet { rebuildEnvelope() } }

    var inputDriveDB: Float = 0
    var process: Float = 40
    var outputGainDB: Float = 0

    private let attackMs: Float = 8
    private let releaseMs: Float = 140

    private var envelope = EnvelopeFollower()

    private func rebuildEnvelope() {
        envelope.configure(sampleRate: sampleRate, attackMs: attackMs, releaseMs: releaseMs)
    }

    func reset() {
        rebuildEnvelope()
        envelope.reset()
    }

    func process(buffers: [UnsafeMutablePointer<Float>], frameCount: Int) {
        guard !buffers.isEmpty else { return }
        let driveGain = dBToLinear(inputDriveDB)
        let thresholdDB = PunchCompressorMapping.thresholdDB(forProcess: process)
        let ratio = PunchCompressorMapping.ratio(forProcess: process)
        let saturationDrive = 1 + clamp(process / 100, 0, 1) * 3
        let makeup = dBToLinear(outputGainDB)
        let channelCount = buffers.count

        for i in 0..<frameCount {
            var peak: Float = 0
            for ch in 0..<channelCount {
                peak = max(peak, abs(buffers[ch][i] * driveGain))
            }
            let envDB = linearToDB(envelope.process(peak))

            var gainReductionDB: Float = 0
            if envDB > thresholdDB {
                let over = envDB - thresholdDB
                gainReductionDB = over - (over / ratio)
            }
            let compGain = dBToLinear(-gainReductionDB)

            for ch in 0..<channelCount {
                let driven = buffers[ch][i] * driveGain
                let compressed = driven * compGain
                let saturated = softClip(compressed * saturationDrive) / max(saturationDrive, 1)
                buffers[ch][i] = saturated * makeup
            }
        }
    }
}

final class PunchCompressorAudioUnit: BaseEffectAudioUnit {
    private let compressorKernel = PunchCompressorKernel()

    override init(componentDescription: AudioComponentDescription,
                   options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        kernel = compressorKernel

        let inputParam = AUParameterTree.createParameter(
            withIdentifier: "input", name: "Input",
            address: 0, min: -30, max: 30, unit: .decibels, unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)
        let processParam = AUParameterTree.createParameter(
            withIdentifier: "process", name: "Process",
            address: 1, min: 0, max: 100, unit: .percent, unitName: "%",
            flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)
        let outputParam = AUParameterTree.createParameter(
            withIdentifier: "output", name: "Output",
            address: 2, min: -30, max: 30, unit: .decibels, unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)

        inputParam.value = 0
        processParam.value = 40
        outputParam.value = 0

        let tree = AUParameterTree.createTree(withChildren: [inputParam, processParam, outputParam])
        parameterTree = tree

        let k = compressorKernel
        tree.implementorValueObserver = { param, value in
            switch param.address {
            case 0: k.inputDriveDB = value
            case 1: k.process = value
            case 2: k.outputGainDB = value
            default: break
            }
        }
        tree.implementorValueProvider = { param in
            switch param.address {
            case 0: return k.inputDriveDB
            case 1: return k.process
            case 2: return k.outputGainDB
            default: return 0
            }
        }
    }
}
