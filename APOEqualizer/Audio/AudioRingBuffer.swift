import Foundation

/// Realtime-safe single-producer/single-consumer ring buffer of planar
/// Float32 audio, bridging the capture and playback engines.
///
/// Both sides run on separate Core Audio realtime threads, so nothing here
/// allocates or locks: reads and writes are index arithmetic over
/// pre-allocated storage, which is safe for one writer and one reader.
final class AudioRingBuffer: @unchecked Sendable {
    let channelCount: Int
    private let capacityFrames: Int
    private var storage: [UnsafeMutablePointer<Float>]
    private var writeIndex: Int = 0
    private var readIndex: Int = 0

    /// - Parameters:
    ///   - channelCount: number of audio channels (e.g. 2 for stereo)
    ///   - capacityFrames: ring size in frames; should comfortably exceed the
    ///     largest expected producer/consumer callback size (default ~0.5s at 48kHz)
    init(channelCount: Int, capacityFrames: Int = 24000) {
        self.channelCount = channelCount
        self.capacityFrames = capacityFrames
        self.storage = (0..<channelCount).map { _ in
            let ptr = UnsafeMutablePointer<Float>.allocate(capacity: capacityFrames)
            ptr.initialize(repeating: 0, count: capacityFrames)
            return ptr
        }
    }

    deinit {
        for ptr in storage {
            ptr.deallocate()
        }
    }

    /// Frames currently available to read. Approximate under concurrent
    /// access (as expected for SPSC), always safe to use as a bound.
    var framesAvailable: Int {
        let w = writeIndex, r = readIndex
        return w >= r ? (w - r) : (capacityFrames - r + w)
    }

    var framesFree: Int {
        capacityFrames - framesAvailable - 1
    }

    func reset() {
        readIndex = 0
        writeIndex = 0
        for ptr in storage {
            ptr.update(repeating: 0, count: capacityFrames)
        }
    }

    /// Writes as many frames as fit; drops the oldest data instead of
    /// blocking if the producer is running faster than the consumer.
    @discardableResult
    func write(from channels: [UnsafePointer<Float>], frameCount: Int) -> Int {
        guard channels.count == channelCount, frameCount > 0 else { return 0 }

        var toWrite = frameCount
        if toWrite > framesFree {
            // Overrun: advance the read pointer to make room, dropping the
            // oldest samples rather than growing unbounded latency.
            let overflow = toWrite - framesFree
            readIndex = (readIndex + overflow) % capacityFrames
        }
        toWrite = min(toWrite, capacityFrames)

        var w = writeIndex
        for ch in 0..<channelCount {
            let src = channels[ch]
            let dst = storage[ch]
            let firstRun = min(toWrite, capacityFrames - w)
            dst.advanced(by: w).update(from: src, count: firstRun)
            let remaining = toWrite - firstRun
            if remaining > 0 {
                dst.update(from: src.advanced(by: firstRun), count: remaining)
            }
        }
        w = (w + toWrite) % capacityFrames
        writeIndex = w
        return toWrite
    }

    /// Reads as many frames as are available into `channels`, zero-filling
    /// any shortfall so an underrun produces silence instead of garbage/clicks.
    @discardableResult
    func read(into channels: [UnsafeMutablePointer<Float>], frameCount: Int) -> Int {
        guard channels.count == channelCount, frameCount > 0 else { return 0 }

        let available = framesAvailable
        let toRead = min(available, frameCount)

        let r = readIndex
        for ch in 0..<channelCount {
            let dst = channels[ch]
            let src = storage[ch]
            let firstRun = min(toRead, capacityFrames - r)
            dst.update(from: src.advanced(by: r), count: firstRun)
            let remaining = toRead - firstRun
            if remaining > 0 {
                dst.advanced(by: firstRun).update(from: src, count: remaining)
            }
            if toRead < frameCount {
                dst.advanced(by: toRead).update(repeating: 0, count: frameCount - toRead)
            }
        }
        readIndex = (r + toRead) % capacityFrames
        return toRead
    }
}
