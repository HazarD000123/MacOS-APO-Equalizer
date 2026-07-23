import AVFoundation
import CoreAudio
import AudioToolbox
import Combine

enum EngineError: LocalizedError {
    case noAudioUnit
    case deviceSetFailed(OSStatus)
    case virtualDeviceMissing
    case noInputDevice
    case noRingBuffer

    var errorDescription: String? {
        switch self {
        case .noAudioUnit: return "Could not access the underlying Core Audio unit."
        case .deviceSetFailed(let status): return "Failed to set the audio device (OSStatus \(status))."
        case .virtualDeviceMissing: return "BlackHole is not installed."
        case .noInputDevice: return "No microphone is selected."
        case .noRingBuffer: return "Capture pipeline wasn't initialized before playback."
        }
    }
}

/// Owns the real-time audio pipeline.
///
/// Microphone -> captureEngine writes into a ring buffer -> playbackEngine
/// reads it through Preamp -> EQ -> plugin rack -> BlackHole. Any app that
/// selects "BlackHole 2ch" as its input then receives the processed audio.
///
/// Two `AVAudioEngine`s are needed because a single engine's input and output
/// nodes share one I/O AudioUnit on macOS and can't target different devices.
/// The ring buffer bridges them.
///
/// Each engine targets its device via `kAudioOutputUnitProperty_CurrentDevice`,
/// so the system-wide default is never modified.
@MainActor
final class AudioEngineManager: ObservableObject {
    @Published private(set) var isRunning = false
    @Published var statusMessage = "Stopped"
    @Published private(set) var availableInputDevices: [AudioDeviceInfo] = []
    @Published var selectedInputDeviceUID: String?
    @Published private(set) var isVirtualDeviceInstalled = false
    @Published private(set) var outputLevel: Float = 0
    @Published private(set) var isMonitoring = false

    @Published var preampGainDB: Float = 0
    @Published var preampLimiterEnabled: Bool = true
    @Published var preampBypassed: Bool = false
    @Published var eqEnabled: Bool = true
    @Published var eqBands: [EQBand] = EQBand.defaultTenBand()
    @Published var pluginSlots: [PluginSlot] = []

    private let captureEngine = AVAudioEngine()
    private let playbackEngine = AVAudioEngine()
    private var ringBuffer: AudioRingBuffer?
    private var sourceNode: AVAudioSourceNode?
    private var preampUnit: AVAudioUnit?
    private var eqUnit: AVAudioUnitEQ?
    private var pluginUnits: [UUID: AVAudioUnit] = [:]
    private var workingFormat: AVAudioFormat?

    /// Optional third engine that plays a copy of the processed signal to a
    /// real output, so you can hear it. BlackHole itself stays silent until
    /// another app picks it up as an input.
    private let monitorEngine = AVAudioEngine()
    private var monitorRingBuffer: AudioRingBuffer?
    private var monitorSourceNode: AVAudioSourceNode?

    init() {
        PluginRegistry.registerAll()
        refreshDevices()
    }

    // MARK: - Devices

    func refreshDevices() {
        availableInputDevices = AudioDeviceManager.inputDevices()
        isVirtualDeviceInstalled = AudioDeviceManager.isVirtualDeviceInstalled()

        if selectedInputDeviceUID == nil || !availableInputDevices.contains(where: { $0.uid == selectedInputDeviceUID }) {
            if let current = AudioDeviceManager.defaultInputDevice(),
               !current.name.localizedCaseInsensitiveContains(AudioDeviceManager.virtualDeviceNameHint) {
                selectedInputDeviceUID = current.uid
            } else {
                selectedInputDeviceUID = availableInputDevices.first?.uid
            }
        }
    }

    private func resolvedInputDevice() -> AudioDeviceInfo? {
        if let uid = selectedInputDeviceUID,
           let id = AudioDeviceManager.deviceID(forUID: uid),
           let info = AudioDeviceManager.info(for: id) {
            return info
        }
        return availableInputDevices.first
    }

    func setInputDevice(_ device: AudioDeviceInfo) async {
        selectedInputDeviceUID = device.uid
        guard isRunning else { return }
        do {
            captureEngine.pause()
            guard let audioUnit = captureEngine.inputNode.audioUnit else { throw EngineError.noAudioUnit }
            try setIONodeDevice(audioUnit, to: device.id)
            try captureEngine.start()
            statusMessage = "Running -- processing \(device.name). Select \"BlackHole 2ch\" as the microphone in any app to hear it."
        } catch {
            statusMessage = "Failed to switch microphone: \(error.localizedDescription)"
        }
    }

    // MARK: - Lifecycle

    func toggleRunning() async {
        if isRunning {
            stop()
        } else {
            await start()
        }
    }

    /// Requests microphone permission up front. Core Audio won't reliably
    /// error out without it -- an unpermitted capture just delivers silence,
    /// which looks identical to the app running and doing nothing.
    private func ensureMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func start() async {
        guard !isRunning else { return }
        statusMessage = "Starting..."
        refreshDevices()

        guard await ensureMicrophonePermission() else {
            statusMessage = "Microphone access is off for this app. Enable it in System Settings > Privacy & Security > Microphone, then press Start again."
            return
        }

        guard let virtualDevice = AudioDeviceManager.virtualLoopbackDevice() else {
            statusMessage = "BlackHole isn't installed -- see Devices for instructions."
            return
        }
        guard let micDevice = resolvedInputDevice() else {
            statusMessage = "No microphone available."
            return
        }

        if let micRate = AudioDeviceManager.nominalSampleRate(micDevice.id) {
            AudioDeviceManager.setNominalSampleRate(virtualDevice.id, rate: micRate)
        }
        let sampleRate = AudioDeviceManager.nominalSampleRate(virtualDevice.id) ?? 48000
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            statusMessage = "Failed to build audio format."
            return
        }
        workingFormat = format

        do {
            try configureCapture(device: micDevice, format: format)
            try await configurePlayback(device: virtualDevice, format: format)

            captureEngine.prepare()
            try captureEngine.start()
            playbackEngine.prepare()
            try playbackEngine.start()

            isRunning = true
            statusMessage = "Running -- processing \(micDevice.name). Select \"BlackHole 2ch\" as the microphone in any app (Zoom, Discord, OBS, etc.) to hear it."
        } catch {
            statusMessage = "Failed to start: \(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        if isMonitoring {
            stopMonitor()
        }

        captureEngine.inputNode.removeTap(onBus: 0)
        captureEngine.stop()

        playbackEngine.mainMixerNode.removeTap(onBus: 0)
        for unit in pluginUnits.values {
            playbackEngine.disconnectNodeOutput(unit)
            playbackEngine.detach(unit)
        }
        pluginUnits.removeAll()
        if let preampUnit {
            playbackEngine.disconnectNodeOutput(preampUnit)
            playbackEngine.detach(preampUnit)
        }
        if let eqUnit {
            playbackEngine.disconnectNodeOutput(eqUnit)
            playbackEngine.detach(eqUnit)
        }
        if let sourceNode {
            playbackEngine.disconnectNodeOutput(sourceNode)
            playbackEngine.detach(sourceNode)
        }
        preampUnit = nil
        eqUnit = nil
        sourceNode = nil
        ringBuffer = nil
        playbackEngine.stop()

        isRunning = false
        outputLevel = 0
        statusMessage = "Stopped"
    }

    /// Sets an I/O node's device and reads it back to confirm it took.
    /// Bluetooth outputs in particular can accept the write without actually
    /// switching, so this retries a few times to let profile negotiation settle.
    private func setIONodeDevice(_ audioUnit: AudioUnit, to deviceID: AudioDeviceID, attempts: Int = 4) throws {
        var lastStatus: OSStatus = noErr
        for attempt in 0..<attempts {
            var mutableID = deviceID
            lastStatus = AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &mutableID, UInt32(MemoryLayout<AudioDeviceID>.size))

            var confirmedID = AudioDeviceID(0)
            var confirmedSize = UInt32(MemoryLayout<AudioDeviceID>.size)
            AudioUnitGetProperty(audioUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &confirmedID, &confirmedSize)
            if lastStatus == noErr && confirmedID == deviceID {
                return
            }
            if attempt < attempts - 1 {
                usleep(150_000)
            }
        }
        throw EngineError.deviceSetFailed(lastStatus)
    }

    // MARK: - Capture engine (real microphone -> ring buffer)

    private func configureCapture(device: AudioDeviceInfo, format: AVAudioFormat) throws {
        captureEngine.stop()
        let input = captureEngine.inputNode
        guard let audioUnit = input.audioUnit else { throw EngineError.noAudioUnit }
        try setIONodeDevice(audioUnit, to: device.id)

        let buffer = AudioRingBuffer(channelCount: 2, capacityFrames: max(8192, Int(format.sampleRate)))
        ringBuffer = buffer

        input.removeTap(onBus: 0)
        let tapFormat = input.inputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { pcmBuffer, _ in
            guard let channelData = pcmBuffer.floatChannelData else { return }
            let frameCount = Int(pcmBuffer.frameLength)
            let channelCount = Int(pcmBuffer.format.channelCount)
            guard channelCount > 0, frameCount > 0 else { return }
            // Built-in mics are usually mono, so duplicate the single channel
            // into both sides rather than dropping the buffer.
            let left = channelData[0]
            let right = channelCount >= 2 ? channelData[1] : channelData[0]
            let pointers: [UnsafePointer<Float>] = [UnsafePointer(left), UnsafePointer(right)]
            buffer.write(from: pointers, frameCount: frameCount)
        }
    }

    // MARK: - Playback engine (ring buffer -> preamp -> EQ -> plugins -> BlackHole)

    private func configurePlayback(device: AudioDeviceInfo, format: AVAudioFormat) async throws {
        playbackEngine.stop()
        guard let ringBuffer else { throw EngineError.noRingBuffer }

        if preampUnit == nil {
            preampUnit = await PluginRegistry.instantiatePreamp()
            if let preampUnit { playbackEngine.attach(preampUnit) }
        }
        applyPreampToUnit()
        if let base = preampUnit?.auAudioUnit as? BaseEffectAudioUnit {
            base.isBypassed = preampBypassed
        }

        if eqUnit == nil {
            let eq = AVAudioUnitEQ(numberOfBands: eqBands.count)
            playbackEngine.attach(eq)
            eqUnit = eq
        }
        applyEQBandsToUnit()
        eqUnit?.bypass = !eqEnabled

        for index in pluginSlots.indices {
            pluginSlots[index] = await instantiateAndAttachPlugin(pluginSlots[index])
        }

        if sourceNode == nil {
            let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
                let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
                guard abl.count >= 2, let l = abl[0].mData, let r = abl[1].mData else { return noErr }
                let pointers = [l.assumingMemoryBound(to: Float.self), r.assumingMemoryBound(to: Float.self)]
                _ = ringBuffer.read(into: pointers, frameCount: Int(frameCount))
                return noErr
            }
            playbackEngine.attach(node)
            sourceNode = node
        }

        guard let outputAudioUnit = playbackEngine.outputNode.audioUnit else { throw EngineError.noAudioUnit }
        try setIONodeDevice(outputAudioUnit, to: device.id)

        rebuildPlaybackConnections()
        installLevelTap()
    }

    /// Disconnects and reconnects the whole playback chain -- used whenever
    /// a plugin is added/removed/reordered. This briefly leaves the graph in
    /// an incomplete state between the disconnect pass and the reconnect
    /// pass, which crashes `AVAudioEngine` if its render thread is actively
    /// pulling audio through it at that moment -- so the engine is paused
    /// first (which keeps all render resources allocated, unlike `stop()`)
    /// and resumed afterward.
    private func rebuildPlaybackConnections() {
        guard let sourceNode, let preampUnit, let eqUnit, let format = workingFormat else { return }

        let wasRunning = playbackEngine.isRunning
        if wasRunning {
            playbackEngine.pause()
        }

        playbackEngine.disconnectNodeOutput(sourceNode)
        playbackEngine.disconnectNodeOutput(preampUnit)
        playbackEngine.disconnectNodeOutput(eqUnit)
        for unit in pluginUnits.values {
            playbackEngine.disconnectNodeOutput(unit)
        }
        playbackEngine.disconnectNodeOutput(playbackEngine.mainMixerNode)

        var chain: [AVAudioNode] = [sourceNode, preampUnit, eqUnit]
        for slot in pluginSlots {
            if let unit = pluginUnits[slot.id] {
                chain.append(unit)
            }
        }
        chain.append(playbackEngine.mainMixerNode)
        chain.append(playbackEngine.outputNode)

        for i in 0..<(chain.count - 1) {
            playbackEngine.connect(chain[i], to: chain[i + 1], format: format)
        }

        if wasRunning {
            do {
                try playbackEngine.start()
            } catch {
                statusMessage = "Failed to rebuild the plugin chain: \(error.localizedDescription)"
            }
        }
    }

    /// `monitorBuffer` is a fixed snapshot captured at call time (nil to
    /// disable monitoring) rather than something read dynamically off
    /// `self` inside the tap -- the tap runs on a realtime audio thread and
    /// this class is main-actor isolated, so toggling monitoring re-installs
    /// the tap with a fresh closure instead of mutating shared state from
    /// the audio thread.
    private func installLevelTap(monitorBuffer: AudioRingBuffer? = nil) {
        playbackEngine.mainMixerNode.removeTap(onBus: 0)
        playbackEngine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] pcmBuffer, _ in
            guard let channelData = pcmBuffer.floatChannelData else { return }
            let frameCount = Int(pcmBuffer.frameLength)
            guard frameCount > 0, pcmBuffer.format.channelCount >= 2 else { return }

            if let monitorBuffer {
                let pointers: [UnsafePointer<Float>] = [UnsafePointer(channelData[0]), UnsafePointer(channelData[1])]
                monitorBuffer.write(from: pointers, frameCount: frameCount)
            }

            var peak: Float = 0
            for i in 0..<frameCount { peak = max(peak, abs(channelData[0][i])) }
            Task { @MainActor [weak self] in
                self?.outputLevel = peak
            }
        }
    }

    // MARK: - Monitor (hear the processed signal directly)

    func setMonitorEnabled(_ enabled: Bool) {
        if enabled {
            startMonitor()
        } else {
            stopMonitor()
        }
    }

    /// Devices worth trying for monitoring, in order: whatever the system
    /// is currently using, then anything with "MacBook"/"Built-in" in its
    /// name (the most reliable targets -- never Bluetooth), then everything
    /// else. Bluetooth outputs are tried first (since that's usually what
    /// you actually want to hear through) but aren't trusted alone, given
    /// how unreliable switching to them has proven to be.
    private func monitorDeviceCandidates() -> [AudioDeviceInfo] {
        var ordered: [AudioDeviceInfo] = []
        if let current = AudioDeviceManager.defaultOutputDevice() {
            ordered.append(current)
        }
        let rest = AudioDeviceManager.outputDevices().filter { device in
            !ordered.contains(where: { $0.id == device.id })
        }
        let builtIn = rest.filter { $0.name.localizedCaseInsensitiveContains("macbook") || $0.name.localizedCaseInsensitiveContains("built-in") }
        let others = rest.filter { !builtIn.contains($0) }
        return ordered + builtIn + others
    }

    private func startMonitor() {
        guard isRunning, let format = workingFormat else {
            statusMessage = "Start the engine before enabling Monitor."
            return
        }
        let candidates = monitorDeviceCandidates()
        guard let audioUnit = monitorEngine.outputNode.audioUnit else {
            statusMessage = "Couldn't access the output unit for monitoring."
            return
        }
        guard !candidates.isEmpty else {
            statusMessage = "No output device found for monitoring."
            return
        }

        let buffer = AudioRingBuffer(channelCount: 2, capacityFrames: max(8192, Int(format.sampleRate)))
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard abl.count >= 2, let l = abl[0].mData, let r = abl[1].mData else { return noErr }
            let pointers = [l.assumingMemoryBound(to: Float.self), r.assumingMemoryBound(to: Float.self)]
            _ = buffer.read(into: pointers, frameCount: Int(frameCount))
            return noErr
        }
        monitorEngine.attach(node)
        monitorEngine.connect(node, to: monitorEngine.mainMixerNode, format: format)
        monitorEngine.connect(monitorEngine.mainMixerNode, to: monitorEngine.outputNode, format: format)
        monitorSourceNode = node

        var lastError: Error?
        for device in candidates {
            do {
                try setIONodeDevice(audioUnit, to: device.id)
                monitorEngine.prepare()
                try monitorEngine.start()

                monitorRingBuffer = buffer
                installLevelTap(monitorBuffer: buffer)
                isMonitoring = true
                statusMessage = device.id == candidates[0].id
                    ? "Running -- monitoring through \(device.name)."
                    : "Running -- monitoring through \(device.name) (couldn't switch to \(candidates[0].name))."
                return
            } catch {
                lastError = error
            }
        }

        statusMessage = "Couldn't start monitoring: \(lastError?.localizedDescription ?? "unknown error")."
        stopMonitor()
    }

    private func stopMonitor() {
        monitorEngine.stop()
        if let monitorSourceNode {
            monitorEngine.disconnectNodeOutput(monitorSourceNode)
            monitorEngine.detach(monitorSourceNode)
        }
        monitorSourceNode = nil
        monitorRingBuffer = nil
        isMonitoring = false
        if isRunning {
            installLevelTap()
        }
    }

    // MARK: - Preamp

    func setPreampGain(_ db: Float) {
        preampGainDB = clamp(db, -24, 50)
        applyPreampToUnit()
    }

    func setPreampLimiterEnabled(_ enabled: Bool) {
        preampLimiterEnabled = enabled
        applyPreampToUnit()
    }

    func setPreampBypassed(_ bypassed: Bool) {
        preampBypassed = bypassed
        if let base = preampUnit?.auAudioUnit as? BaseEffectAudioUnit {
            base.isBypassed = bypassed
        }
    }

    private func applyPreampToUnit() {
        guard let preampUnit, let tree = preampUnit.auAudioUnit.parameterTree else { return }
        tree.allParameters.first(where: { $0.identifier == "gain" })?.value = preampGainDB
        tree.allParameters.first(where: { $0.identifier == "limiter" })?.value = preampLimiterEnabled ? 1 : 0
    }

    // MARK: - EQ

    func updateEQBand(_ band: EQBand) {
        guard let index = eqBands.firstIndex(where: { $0.id == band.id }) else { return }
        eqBands[index] = band
        guard let eqUnit, index < eqUnit.bands.count else { return }
        let filter = eqUnit.bands[index]
        filter.filterType = band.filterType.avFilterType
        filter.frequency = band.frequency
        filter.bandwidth = band.bandwidth
        filter.gain = band.gain
        filter.bypass = band.bypass
    }

    func setEQEnabled(_ enabled: Bool) {
        eqEnabled = enabled
        eqUnit?.bypass = !enabled
    }

    func resetEQ() {
        eqBands = EQBand.defaultTenBand()
        applyEQBandsToUnit()
    }

    /// Applies a quick curve's gains on top of the current bands, leaving
    /// frequency/filter type/bypass untouched -- only the shape changes.
    func applyEQCurve(_ curve: EQCurvePreset) {
        for i in eqBands.indices where i < curve.gains.count {
            eqBands[i].gain = curve.gains[i]
        }
        applyEQBandsToUnit()
    }

    private func applyEQBandsToUnit() {
        guard let eqUnit else { return }
        for (index, band) in eqBands.enumerated() where index < eqUnit.bands.count {
            let filter = eqUnit.bands[index]
            filter.filterType = band.filterType.avFilterType
            filter.frequency = band.frequency
            filter.bandwidth = band.bandwidth
            filter.gain = band.gain
            filter.bypass = band.bypass
        }
    }

    // MARK: - Plugin rack

    func addPlugin(_ kind: PluginKind) async {
        var slot = PluginSlot(kind: kind)
        if isRunning {
            slot = await instantiateAndAttachPlugin(slot)
        }
        pluginSlots.append(slot)
        if isRunning {
            rebuildPlaybackConnections()
        }
    }

    func removePlugin(_ id: UUID) {
        pluginSlots.removeAll { $0.id == id }

        let wasRunning = playbackEngine.isRunning
        if wasRunning { playbackEngine.pause() }

        if let unit = pluginUnits.removeValue(forKey: id) {
            playbackEngine.disconnectNodeOutput(unit)
            playbackEngine.detach(unit)
        }
        if isRunning {
            rebuildPlaybackConnections()
        }

        if wasRunning {
            do {
                try playbackEngine.start()
            } catch {
                statusMessage = "Failed to remove plugin: \(error.localizedDescription)"
            }
        }
    }

    func movePlugins(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        pluginSlots.move(fromOffsets: offsets, toOffset: destination)
        if isRunning {
            rebuildPlaybackConnections()
        }
    }

    func setPluginBypass(_ id: UUID, bypass: Bool) {
        guard let index = pluginSlots.firstIndex(where: { $0.id == id }) else { return }
        pluginSlots[index].bypass = bypass
        if let unit = pluginUnits[id], let base = unit.auAudioUnit as? BaseEffectAudioUnit {
            base.isBypassed = bypass
        }
    }

    func setPluginParameter(_ id: UUID, identifier: String, value: Float) {
        guard let index = pluginSlots.firstIndex(where: { $0.id == id }) else { return }
        pluginSlots[index].parameters[identifier] = value
        guard let unit = pluginUnits[id], let tree = unit.auAudioUnit.parameterTree else { return }
        tree.allParameters.first(where: { $0.identifier == identifier })?.value = value
    }

    @discardableResult
    private func instantiateAndAttachPlugin(_ inputSlot: PluginSlot) async -> PluginSlot {
        var slot = inputSlot
        guard let unit = await PluginRegistry.instantiate(slot.kind) else { return slot }
        playbackEngine.attach(unit)
        pluginUnits[slot.id] = unit

        if let base = unit.auAudioUnit as? BaseEffectAudioUnit {
            base.isBypassed = slot.bypass
        }
        if let tree = unit.auAudioUnit.parameterTree {
            if slot.parameters.isEmpty {
                for param in tree.allParameters {
                    slot.parameters[param.identifier] = param.value
                }
            } else {
                for param in tree.allParameters {
                    if let value = slot.parameters[param.identifier] {
                        param.value = value
                    }
                }
            }
        }
        return slot
    }

    // MARK: - Presets

    func currentPreset(named name: String) -> Preset {
        Preset(name: name,
               preampGainDB: preampGainDB,
               preampLimiterEnabled: preampLimiterEnabled,
               eqEnabled: eqEnabled,
               eqBands: eqBands,
               pluginSlots: pluginSlots)
    }

    func applyPreset(_ preset: Preset) async {
        preampGainDB = preset.preampGainDB
        preampLimiterEnabled = preset.preampLimiterEnabled
        eqEnabled = preset.eqEnabled
        eqBands = preset.eqBands
        applyPreampToUnit()
        applyEQBandsToUnit()
        eqUnit?.bypass = !eqEnabled

        let wasRunning = playbackEngine.isRunning
        if wasRunning { playbackEngine.pause() }

        for unit in pluginUnits.values {
            playbackEngine.disconnectNodeOutput(unit)
            playbackEngine.detach(unit)
        }
        pluginUnits.removeAll()
        pluginSlots = preset.pluginSlots

        if isRunning {
            for index in pluginSlots.indices {
                pluginSlots[index] = await instantiateAndAttachPlugin(pluginSlots[index])
            }
            rebuildPlaybackConnections()
        }

        if wasRunning {
            do {
                try playbackEngine.start()
            } catch {
                statusMessage = "Failed to apply preset: \(error.localizedDescription)"
            }
        }
    }
}
