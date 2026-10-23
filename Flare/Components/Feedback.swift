import AVFoundation
import CoreHaptics
import UIKit

/// Haptics: UIKit generators for ticks, Core Haptics for the stretch "snap".
@MainActor
enum Haptics {
    private static let engine: CHHapticEngine? = {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics, let e = try? CHHapticEngine() else { return nil }
        e.isAutoShutdownEnabled = true
        return e
    }()

    static func tick(_ intensity: CGFloat) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: min(1, max(0.1, intensity)))
    }

    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }

    /// Viscous pull that releases into a sharp pop.
    static func snap() {
        guard let engine else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            return
        }
        let events = [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15),
            ], relativeTime: 0, duration: 0.16),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
            ], relativeTime: 0.16),
        ]
        try? engine.start()
        if let pattern = try? CHHapticPattern(events: events, parameters: []),
           let player = try? engine.makePlayer(with: pattern) {
            try? player.start(atTime: CHHapticTimeImmediate)
        }
    }
}

/// Procedural liquid blips and chimes on one AVAudioSourceNode. No audio files.
final class Sound: @unchecked Sendable {
    static let shared = Sound()

    private struct Voice {
        var f0: Double, f1: Double, dur: Double, delay: Double, gain: Double, saw: Bool
        var t = 0.0, phase = 0.0
    }

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var voices: [Voice] = []
    private var rate = 44_100.0
    private var started = false

    private init() {}

    func blip() { play([Voice(f0: 900, f1: 380, dur: 0.11, delay: 0, gain: 0.45, saw: false)]) }

    func drip() {
        play([Voice(f0: 280, f1: 1_150, dur: 0.08, delay: 0, gain: 0.4, saw: false),
              Voice(f0: 1_150, f1: 620, dur: 0.12, delay: 0.07, gain: 0.3, saw: false)])
    }

    func chime() {
        play([1_046.5, 1_318.5, 1_568].enumerated().map { i, f in
            Voice(f0: f, f1: f, dur: 0.55, delay: Double(i) * 0.09, gain: 0.28, saw: false)
        })
    }

    func buzz() {
        play([Voice(f0: 120, f1: 85, dur: 0.32, delay: 0, gain: 0.35, saw: true),
              Voice(f0: 125, f1: 90, dur: 0.32, delay: 0.02, gain: 0.25, saw: true)])
    }

    private func play(_ v: [Voice]) {
        startIfNeeded()
        lock.lock()
        voices.append(contentsOf: v)
        lock.unlock()
    }

    private func startIfNeeded() {
        guard !started else { return }
        started = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        let hw = engine.outputNode.outputFormat(forBus: 0).sampleRate
        rate = hw > 0 ? hw : 44_100
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { return }
        let node = AVAudioSourceNode(format: format) { [unowned self] _, _, frames, abl in
            self.render(Int(frames), abl)
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.4
        try? engine.start()
    }

    private func render(_ frames: Int, _ abl: UnsafeMutablePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(abl)
        guard let out = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else { return }
        let dt = 1 / rate
        lock.lock()
        defer { lock.unlock() }
        for i in 0..<frames {
            var sample = 0.0
            for v in voices.indices {
                voices[v].t += dt
                let local = voices[v].t - voices[v].delay
                guard local > 0, local < voices[v].dur else { continue }
                let x = local / voices[v].dur
                let f = voices[v].f0 + (voices[v].f1 - voices[v].f0) * x
                voices[v].phase += 2 * .pi * f * dt
                if voices[v].phase > 2 * .pi { voices[v].phase -= 2 * .pi }
                let osc = voices[v].saw ? (voices[v].phase / .pi - 1) * 0.6 : sin(voices[v].phase)
                let env = min(1, local * 250) * (1 - x) * (1 - x)
                sample += osc * env * voices[v].gain
            }
            out[i] = Float(max(-1, min(1, sample)))
        }
        for b in buffers.dropFirst() {
            b.mData?.copyMemory(from: out, byteCount: frames * MemoryLayout<Float>.size)
        }
        voices.removeAll { $0.t > $0.delay + $0.dur }
    }
}
