import AVFoundation
import AudioToolbox

protocol EffectKernel: AnyObject {
    var bypassed: Bool { get set }
    var sampleRate: Double { get set }
    func reset()
    func process(buffers: [UnsafeMutablePointer<Float>], frameCount: Int)
}

class BaseEffectAudioUnit: AUAudioUnit {
    private var _inputBus: AUAudioUnitBus!
    private var _outputBus: AUAudioUnitBus!
    private var _inputBusArray: AUAudioUnitBusArray!
    private var _outputBusArray: AUAudioUnitBusArray!

    var kernel: EffectKernel!

    override init(componentDescription: AudioComponentDescription,
                   options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)

        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        _inputBus = try AUAudioUnitBus(format: format)
        _outputBus = try AUAudioUnitBus(format: format)
        _inputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [_inputBus])
        _outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [_outputBus])

        maximumFramesToRender = 4096
    }

    override var inputBusses: AUAudioUnitBusArray { _inputBusArray }
    override var outputBusses: AUAudioUnitBusArray { _outputBusArray }
    override var canProcessInPlace: Bool { true }

    override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        kernel.sampleRate = outputBusses[0].format.sampleRate
        kernel.reset()
    }

    override func deallocateRenderResources() {
        super.deallocateRenderResources()
    }

    var isBypassed: Bool {
        get { kernel.bypassed }
        set { kernel.bypassed = newValue }
    }

    final override var internalRenderBlock: AUInternalRenderBlock {
        let kernel = self.kernel!
        let channelCount = Int(_outputBus.format.channelCount)

        return { actionFlags, timestamp, frameCount, _, outputData, _, pullInputBlock in
            guard let pullInputBlock = pullInputBlock else {
                return kAudioUnitErr_NoConnection
            }

            var pullFlags: AudioUnitRenderActionFlags = []
            let pullStatus = pullInputBlock(&pullFlags, timestamp, frameCount, 0, outputData)
            guard pullStatus == noErr else { return pullStatus }

            if kernel.bypassed {
                return noErr
            }

            let abl = UnsafeMutableAudioBufferListPointer(outputData)
            guard abl.count >= channelCount else { return noErr }

            var pointers: [UnsafeMutablePointer<Float>] = []
            pointers.reserveCapacity(channelCount)
            for i in 0..<channelCount {
                guard let raw = abl[i].mData else { return noErr }
                pointers.append(raw.assumingMemoryBound(to: Float.self))
            }

            kernel.process(buffers: pointers, frameCount: Int(frameCount))
            return noErr
        }
    }
}

func fourCC(_ string: String) -> OSType {
    precondition(string.utf8.count == 4, "fourCC requires exactly 4 characters")
    var result: OSType = 0
    for byte in string.utf8 {
        result = (result << 8) | OSType(byte)
    }
    return result
}
