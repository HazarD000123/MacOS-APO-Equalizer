import Foundation

@inline(__always) func dBToLinear(_ dB: Float) -> Float {
    pow(10.0, dB / 20.0)
}

@inline(__always) func linearToDB(_ linear: Float) -> Float {
    20.0 * log10(max(linear, 1e-9))
}

@inline(__always) func clamp<T: Comparable>(_ value: T, _ lo: T, _ hi: T) -> T {
    min(max(value, lo), hi)
}

@inline(__always) func softClip(_ x: Float) -> Float {
    tanh(x)
}

struct Biquad {
    var b0: Float = 1, b1: Float = 0, b2: Float = 0
    var a1: Float = 0, a2: Float = 0
    private var x1: Float = 0, x2: Float = 0
    private var y1: Float = 0, y2: Float = 0

    mutating func reset() {
        x1 = 0; x2 = 0; y1 = 0; y2 = 0
    }

    mutating func updateCoefficients(from other: Biquad) {
        b0 = other.b0; b1 = other.b1; b2 = other.b2
        a1 = other.a1; a2 = other.a2
    }

    @inline(__always) mutating func process(_ x: Float) -> Float {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x
        y2 = y1; y1 = y
        return y
    }

    static func lowPass(sampleRate: Double, frequency: Float, q: Float = 0.707) -> Biquad {
        let w0 = 2.0 * Double.pi * Double(frequency) / sampleRate
        let alpha = sin(w0) / (2.0 * Double(q))
        let cosw0 = cos(w0)
        let a0 = 1 + alpha
        var f = Biquad()
        f.b0 = Float(((1 - cosw0) / 2) / a0)
        f.b1 = Float((1 - cosw0) / a0)
        f.b2 = f.b0
        f.a1 = Float((-2 * cosw0) / a0)
        f.a2 = Float((1 - alpha) / a0)
        return f
    }

    static func highPass(sampleRate: Double, frequency: Float, q: Float = 0.707) -> Biquad {
        let w0 = 2.0 * Double.pi * Double(frequency) / sampleRate
        let alpha = sin(w0) / (2.0 * Double(q))
        let cosw0 = cos(w0)
        let a0 = 1 + alpha
        var f = Biquad()
        f.b0 = Float(((1 + cosw0) / 2) / a0)
        f.b1 = Float(-(1 + cosw0) / a0)
        f.b2 = f.b0
        f.a1 = Float((-2 * cosw0) / a0)
        f.a2 = Float((1 - alpha) / a0)
        return f
    }

    static func allPass(sampleRate: Double, frequency: Float, q: Float = 0.7) -> Biquad {
        let w0 = 2.0 * Double.pi * Double(frequency) / sampleRate
        let alpha = sin(w0) / (2.0 * Double(q))
        let cosw0 = cos(w0)
        let a0 = 1 + alpha
        var f = Biquad()
        f.b0 = Float((1 - alpha) / a0)
        f.b1 = Float((-2 * cosw0) / a0)
        f.b2 = 1
        f.a1 = Float((-2 * cosw0) / a0)
        f.a2 = Float((1 - alpha) / a0)
        return f
    }

    static func lowShelf(sampleRate: Double, frequency: Float, gainDB: Float, q: Float = 0.707) -> Biquad {
        let a = pow(10.0, Double(gainDB) / 40.0)
        let w0 = 2.0 * Double.pi * Double(frequency) / sampleRate
        let cosw0 = cos(w0)
        let alpha = sin(w0) / 2.0 * sqrt((a + 1 / a) * (1 / Double(q) - 1) + 2)
        let sqrtA = sqrt(a)

        let b0 = a * ((a + 1) - (a - 1) * cosw0 + 2 * sqrtA * alpha)
        let b1 = 2 * a * ((a - 1) - (a + 1) * cosw0)
        let b2 = a * ((a + 1) - (a - 1) * cosw0 - 2 * sqrtA * alpha)
        let a0 = (a + 1) + (a - 1) * cosw0 + 2 * sqrtA * alpha
        let a1 = -2 * ((a - 1) + (a + 1) * cosw0)
        let a2 = (a + 1) + (a - 1) * cosw0 - 2 * sqrtA * alpha

        var f = Biquad()
        f.b0 = Float(b0 / a0); f.b1 = Float(b1 / a0); f.b2 = Float(b2 / a0)
        f.a1 = Float(a1 / a0); f.a2 = Float(a2 / a0)
        return f
    }

    static func highShelf(sampleRate: Double, frequency: Float, gainDB: Float, q: Float = 0.707) -> Biquad {
        let a = pow(10.0, Double(gainDB) / 40.0)
        let w0 = 2.0 * Double.pi * Double(frequency) / sampleRate
        let cosw0 = cos(w0)
        let alpha = sin(w0) / 2.0 * sqrt((a + 1 / a) * (1 / Double(q) - 1) + 2)
        let sqrtA = sqrt(a)

        let b0 = a * ((a + 1) + (a - 1) * cosw0 + 2 * sqrtA * alpha)
        let b1 = -2 * a * ((a - 1) + (a + 1) * cosw0)
        let b2 = a * ((a + 1) + (a - 1) * cosw0 - 2 * sqrtA * alpha)
        let a0 = (a + 1) - (a - 1) * cosw0 + 2 * sqrtA * alpha
        let a1 = 2 * ((a - 1) - (a + 1) * cosw0)
        let a2 = (a + 1) - (a - 1) * cosw0 - 2 * sqrtA * alpha

        var f = Biquad()
        f.b0 = Float(b0 / a0); f.b1 = Float(b1 / a0); f.b2 = Float(b2 / a0)
        f.a1 = Float(a1 / a0); f.a2 = Float(a2 / a0)
        return f
    }

    static func peaking(sampleRate: Double, frequency: Float, gainDB: Float, q: Float = 0.8) -> Biquad {
        let a = pow(10.0, Double(gainDB) / 40.0)
        let w0 = 2.0 * Double.pi * Double(frequency) / sampleRate
        let alpha = sin(w0) / (2.0 * Double(q))
        let cosw0 = cos(w0)

        let b0 = 1 + alpha * a
        let b1 = -2 * cosw0
        let b2 = 1 - alpha * a
        let a0 = 1 + alpha / a
        let a1 = -2 * cosw0
        let a2 = 1 - alpha / a

        var f = Biquad()
        f.b0 = Float(b0 / a0); f.b1 = Float(b1 / a0); f.b2 = Float(b2 / a0)
        f.a1 = Float(a1 / a0); f.a2 = Float(a2 / a0)
        return f
    }
}

final class DelayLine {
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private(set) var capacity: Int

    init(maxDelaySamples: Int) {
        capacity = max(1, maxDelaySamples)
        buffer = [Float](repeating: 0, count: capacity)
    }

    func reset() {
        for i in 0..<buffer.count { buffer[i] = 0 }
        writeIndex = 0
    }

    @inline(__always) func process(_ input: Float, delaySamples: Int) -> Float {
        buffer[writeIndex] = input
        let delay = clamp(delaySamples, 0, capacity - 1)
        var readIndex = writeIndex - delay
        if readIndex < 0 { readIndex += capacity }
        let output = buffer[readIndex]
        writeIndex += 1
        if writeIndex >= capacity { writeIndex = 0 }
        return output
    }
}

struct EnvelopeFollower {
    var attackCoeff: Float = 0
    var releaseCoeff: Float = 0
    private var envelope: Float = 0

    mutating func configure(sampleRate: Double, attackMs: Float, releaseMs: Float) {
        attackCoeff = expf(-1.0 / (Float(sampleRate) * max(attackMs, 0.01) / 1000.0))
        releaseCoeff = expf(-1.0 / (Float(sampleRate) * max(releaseMs, 0.01) / 1000.0))
    }

    mutating func reset() { envelope = 0 }

    @inline(__always) mutating func process(_ rectified: Float) -> Float {
        let coeff = rectified > envelope ? attackCoeff : releaseCoeff
        envelope = rectified + coeff * (envelope - rectified)
        return envelope
    }
}
