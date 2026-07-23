import Foundation

final class AudioRingBuffer: @unchecked Sendable {
    let channelCount: Int
    private let capacityFrames: Int
    private var storage: [UnsafeMutablePointer<Float>]
    private var writeIndex: Int = 0
    private var readIndex: Int = 0

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

    @discardableResult
    func write(from channels: [UnsafePointer<Float>], frameCount: Int) -> Int {
        guard channels.count == channelCount, frameCount > 0 else { return 0 }

        var toWrite = frameCount
        if toWrite > framesFree {
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
