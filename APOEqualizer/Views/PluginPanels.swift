import SwiftUI

@MainActor
private func paramBinding(_ engine: AudioEngineManager, _ slot: PluginSlot, _ identifier: String, _ fallback: Float) -> Binding<Float> {
    Binding(
        get: { slot.parameters[identifier] ?? fallback },
        set: { engine.setPluginParameter(slot.id, identifier: identifier, value: $0) }
    )
}

private func fmtHz(_ v: Float) -> String { String(format: "%.0f Hz", v) }
private func fmtPercent(_ v: Float) -> String { String(format: "%.0f%%", v) }
private func fmtDB(_ v: Float) -> String { String(format: "%+.1f dB", v) }
private func fmtPan(_ pan: Float) -> String {
    if abs(pan) < 0.05 { return "Center" }
    return String(format: "%.1fms %@", abs(pan), pan > 0 ? "R" : "L")
}

struct PluginPanelView: View {
    @EnvironmentObject var engine: AudioEngineManager
    let slot: PluginSlot

    var body: some View {
        switch slot.kind {
        case .toneShaper: ToneShaperPanel(slot: slot).environmentObject(engine)
        case .haasWidener: HaasWidenerPanel(slot: slot).environmentObject(engine)
        case .stereoImager: StereoImagerPanel(slot: slot).environmentObject(engine)
        case .punchCompressor: PunchCompressorPanel(slot: slot).environmentObject(engine)
        case .maximizer: MaximizerPanel(slot: slot).environmentObject(engine)
        }
    }
}

struct MaximizerPanel: View {
    @EnvironmentObject var engine: AudioEngineManager
    let slot: PluginSlot
    private let tint = PluginKind.maximizer.accentColor

    var body: some View {
        let drive = paramBinding(engine, slot, "drive", 12)
        let loudness = paramBinding(engine, slot, "loudness", 0)
        let output = paramBinding(engine, slot, "output", 0)

        PluginChrome(title: "Maximizer", subtitle: "Hard-Clip Loudness", tint: tint) {
            HStack(alignment: .top, spacing: 24) {
                ClipMeterGraphic(drive: drive.wrappedValue, loudness: loudness.wrappedValue, tint: tint)
                    .frame(width: 64, height: 60)

                HardwareKnobView(value: drive, range: 0...48, label: "Drive", valueText: String(format: "%.0f dB", drive.wrappedValue), finish: .dark, tint: tint, resetValue: 12)
                HardwareKnobView(value: loudness, range: 0...100, label: "Loudness", valueText: fmtPercent(loudness.wrappedValue), finish: .dark, tint: tint, resetValue: 0)
                HardwareKnobView(value: output, range: -24...0, label: "Output", valueText: fmtDB(output.wrappedValue), finish: .dark, tint: tint, diameter: 40, resetValue: 0)
            }
        }
    }
}

private struct ClipMeterGraphic: View {
    let drive: Float
    let loudness: Float
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let midY = h / 2
            let hardness = min(1, drive / 24 + loudness / 200)
            let amp = (midY - 4)
            let flatTop = amp * CGFloat(hardness)

            Path { path in
                let steps = 48
                for s in 0...steps {
                    let x = w * CGFloat(s) / CGFloat(steps)
                    let phase = Double(s) / Double(steps) * 2 * .pi
                    var v = CGFloat(sin(phase)) * amp * 1.6
                    if v > amp - flatTop { v = amp - flatTop }
                    if v < -(amp - flatTop) { v = -(amp - flatTop) }
                    let y = midY - v
                    if s == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            ForEach([midY - amp, midY + amp], id: \.self) { railY in
                Path { p in
                    p.move(to: CGPoint(x: 0, y: railY))
                    p.addLine(to: CGPoint(x: w, y: railY))
                }
                .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
        }
        .animation(.easeOut(duration: 0.15), value: drive)
        .animation(.easeOut(duration: 0.15), value: loudness)
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.35)))
    }
}

struct ToneShaperPanel: View {
    @EnvironmentObject var engine: AudioEngineManager
    let slot: PluginSlot
    private let tint = PluginKind.toneShaper.accentColor

    var body: some View {
        let low = paramBinding(engine, slot, "low", 0)
        let mid = paramBinding(engine, slot, "mid", 0)
        let high = paramBinding(engine, slot, "high", 0)
        let output = paramBinding(engine, slot, "outputGain", 0)

        PluginChrome(title: "Tone Shaper", subtitle: "Baxandall Tone EQ", tint: tint) {
            HStack(alignment: .top, spacing: 24) {
                TiltCurveGraphic(low: low.wrappedValue, mid: mid.wrappedValue, high: high.wrappedValue, tint: tint)
                    .frame(width: 64, height: 60)

                HardwareKnobView(value: low, range: -15...15, label: "Low", valueText: fmtDB(low.wrappedValue), finish: .light, tint: tint, resetValue: 0)
                HardwareKnobView(value: mid, range: -15...15, label: "Mid", valueText: fmtDB(mid.wrappedValue), finish: .light, tint: tint, resetValue: 0)
                HardwareKnobView(value: high, range: -15...15, label: "High", valueText: fmtDB(high.wrappedValue), finish: .light, tint: tint, resetValue: 0)
                HardwareKnobView(value: output, range: -15...15, label: "Output", valueText: fmtDB(output.wrappedValue), finish: .light, tint: tint, diameter: 40, resetValue: 0)
            }
        }
    }
}

private struct TiltCurveGraphic: View {
    let low: Float
    let mid: Float
    let high: Float
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let midY = h / 2
            let y: (Float) -> CGFloat = { gainDB in
                midY - CGFloat(gainDB / 15) * (midY - 4)
            }

            Path { path in
                path.move(to: CGPoint(x: 0, y: midY))
                path.addLine(to: CGPoint(x: w, y: midY))
            }
            .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))

            Path { path in
                path.move(to: CGPoint(x: 0, y: y(low)))
                path.addLine(to: CGPoint(x: w * 0.5, y: y(mid)))
                path.addLine(to: CGPoint(x: w, y: y(high)))
            }
            .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .animation(.easeOut(duration: 0.15), value: low)
        .animation(.easeOut(duration: 0.15), value: mid)
        .animation(.easeOut(duration: 0.15), value: high)
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.35)))
    }
}

struct HaasWidenerPanel: View {
    @EnvironmentObject var engine: AudioEngineManager
    let slot: PluginSlot
    private let tint = PluginKind.haasWidener.accentColor

    var body: some View {
        let pan = paramBinding(engine, slot, "pan", 15)
        let routing = paramBinding(engine, slot, "routing", 0)

        PluginChrome(title: "Haas Widener", subtitle: "Psychoacoustic Delay Pan", tint: tint) {
            VStack(spacing: 18) {
                HStack(spacing: 30) {
                    HardwareKnobView(value: pan, range: -40...40, label: "Delay Pan", valueText: fmtPan(pan.wrappedValue), finish: .dark, tint: tint, diameter: 68, resetValue: 0)
                    HaasDiagram(pan: pan.wrappedValue, tint: tint)
                        .frame(width: 90, height: 68)
                }

                VStack(spacing: 5) {
                    Text("INPUT ROUTING")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.5))
                    PillSelector(options: ["Mono", "Stereo", "Dual L", "Dual R"], selection: Binding(
                        get: { Int(routing.wrappedValue.rounded()) },
                        set: { routing.wrappedValue = Float($0) }
                    ), tint: tint)
                }
            }
        }
    }
}

private struct HaasDiagram: View {
    let pan: Float
    let tint: Color

    var body: some View {
        let offset = CGFloat(clamp(pan / 40, -1, 1)) * 24
        ZStack {
            Capsule().fill(Color.white.opacity(0.12)).frame(height: 1.5)
            HStack(spacing: 44) {
                channelDot("L")
                channelDot("R")
            }
            Circle()
                .fill(tint)
                .frame(width: 11, height: 11)
                .shadow(color: tint.opacity(0.7), radius: 4)
                .offset(x: offset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.15), value: pan)
    }

    private func channelDot(_ label: String) -> some View {
        VStack(spacing: 4) {
            Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5).frame(width: 16, height: 16)
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.5))
        }
    }
}

struct StereoImagerPanel: View {
    @EnvironmentObject var engine: AudioEngineManager
    let slot: PluginSlot
    private let tint = PluginKind.stereoImager.accentColor

    var body: some View {
        let width = paramBinding(engine, slot, "width", 130)
        let bassMono = paramBinding(engine, slot, "bassMono", 120)
        let output = paramBinding(engine, slot, "outputGain", 0)

        PluginChrome(title: "Stereo Imager", subtitle: "Mid / Side Width", tint: tint) {
            VStack(spacing: 18) {
                BowtieGraphic(width: width.wrappedValue, tint: tint)
                    .frame(height: 70)

                HStack(spacing: 30) {
                    HardwareKnobView(value: width, range: 0...200, label: "Width", valueText: fmtPercent(width.wrappedValue), finish: .dark, tint: tint, resetValue: 100)
                    HardwareKnobView(value: bassMono, range: 0...300, label: "Bass Mono", valueText: fmtHz(bassMono.wrappedValue), finish: .dark, tint: tint, resetValue: 120)
                    HardwareKnobView(value: output, range: -12...12, label: "Output", valueText: fmtDB(output.wrappedValue), finish: .dark, tint: tint, resetValue: 0)
                }
            }
        }
    }
}

private struct BowtieGraphic: View {
    let width: Float
    let tint: Color

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let count = 16
                let spread = CGFloat(min(max(width, 0), 200) / 200)
                let reach = size.width / 2 * (0.2 + 0.8 * spread)

                for i in 0..<count {
                    let t = CGFloat(i) / CGFloat(count - 1)
                    let yOffset = (t - 0.5) * size.height
                    let opacity = max(0.08, 0.6 - abs(t - 0.5) * 0.9)

                    var left = Path()
                    left.move(to: CGPoint(x: center.x - 3, y: center.y))
                    left.addLine(to: CGPoint(x: center.x - reach, y: center.y + yOffset))
                    context.stroke(left, with: .color(tint.opacity(opacity)), lineWidth: 1.1)

                    var right = Path()
                    right.move(to: CGPoint(x: center.x + 3, y: center.y))
                    right.addLine(to: CGPoint(x: center.x + reach, y: center.y + yOffset))
                    context.stroke(right, with: .color(tint.opacity(opacity)), lineWidth: 1.1)
                }
            }
            .animation(.easeOut(duration: 0.15), value: width)

            Text(fmtPercent(width))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.55)))
        }
    }
}

struct PunchCompressorPanel: View {
    @EnvironmentObject var engine: AudioEngineManager
    let slot: PluginSlot
    private let tint = PluginKind.punchCompressor.accentColor

    var body: some View {
        let input = paramBinding(engine, slot, "input", 0)
        let process = paramBinding(engine, slot, "process", 40)
        let output = paramBinding(engine, slot, "output", 0)

        PluginChrome(title: "Punch Compressor", subtitle: "One-Knob Drum Bus", tint: tint) {
            HStack(alignment: .top, spacing: 26) {
                CompressionCurveGraphic(
                    thresholdDB: PunchCompressorMapping.thresholdDB(forProcess: process.wrappedValue),
                    ratio: PunchCompressorMapping.ratio(forProcess: process.wrappedValue),
                    tint: tint
                )
                .frame(width: 68, height: 60)

                HardwareKnobView(value: input, range: -30...30, label: "Input", valueText: fmtDB(input.wrappedValue), finish: .dark, tint: tint, resetValue: 0)
                HardwareKnobView(value: process, range: 0...100, label: "Process", valueText: fmtPercent(process.wrappedValue), finish: .dark, tint: tint, diameter: 64, resetValue: 40)
                HardwareKnobView(value: output, range: -30...30, label: "Output", valueText: fmtDB(output.wrappedValue), finish: .dark, tint: tint, resetValue: 0)
            }
        }
    }
}

private struct CompressionCurveGraphic: View {
    let thresholdDB: Float
    let ratio: Float
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let tPos = CGFloat((thresholdDB + 60) / 60).clamped(to: 0...1)
            let outAtOne = tPos + (1 - tPos) / CGFloat(max(ratio, 1))

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: w, y: 0))
                }
                .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))

                Path { path in
                    path.move(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: tPos * w, y: h - tPos * h))
                    path.addLine(to: CGPoint(x: w, y: h - outAtOne * h))
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .animation(.easeOut(duration: 0.15), value: thresholdDB)
        .animation(.easeOut(duration: 0.15), value: ratio)
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.35)))
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
