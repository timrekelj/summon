import AVFoundation
import Observation
import SwiftUI

/// Short interface sounds, synthesized once from plain sine waves with soft edges so they stay clean and click-free.
@Observable
final class SoundEffects {
    enum Sound {
        /// Reordering: a tick each time the dragged shortcut passes a row.
        case tick, pickUp, drop
        case recordStart, recorded, recordCancel, recordClear, invalid
        case toggleOn, toggleOff
        /// A shortcut brings its app forward or hides it.
        case summon, hide
    }

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let engine = AVAudioEngine()
    /// A few voices so quick sounds can overlap instead of cutting each other off.
    @ObservationIgnored private let players = (0..<6).map { _ in AVAudioPlayerNode() }
    @ObservationIgnored private var nextPlayer = 0
    @ObservationIgnored private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    @ObservationIgnored private var idleTask: Task<Void, Never>?

    private static let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!

    init(settings: AppSettings) {
        self.settings = settings
        for player in players {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: Self.format)
        }
    }

    func play(_ sound: Sound) {
        guard settings.playsSounds else { return }
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        let buffer = buffers[sound] ?? Self.render(sound)
        buffers[sound] = buffer

        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
        stopWhenIdle()
    }

    /// Wraps a toggle's binding so flipping it clicks. Only user changes go through the binding, so nothing plays at launch.
    /// The value is set first: turning sounds on confirms with a click, turning them off stays silent.
    func clicking(_ binding: Binding<Bool>) -> Binding<Bool> {
        Binding {
            binding.wrappedValue
        } set: { isOn in
            binding.wrappedValue = isOn
            self.play(isOn ? .toggleOn : .toggleOff)
        }
    }

    /// A running engine keeps the audio hardware awake, so stop it after a few quiet seconds.
    private func stopWhenIdle() {
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.engine.stop()
        }
    }

    // MARK: Synthesis

    /// One sine voice: starts after `delay`, glides from `from` toward `to` and fades out exponentially.
    private struct Voice {
        var delay = 0.0
        var from: Double
        var to: Double
        /// Time constant of the pitch glide, in seconds.
        var glide = 0.02
        var level = 1.0
        var attack = 0.001
        /// Time constant of the fade, in seconds.
        var decay: Double
    }

    /// The voices that make up a sound, and its peak level.
    private static func recipe(for sound: Sound) -> (voices: [Voice], gain: Double) {
        switch sound {
        case .tick:
            (tick(pitch: 1), 0.26)
        case .toggleOn:
            (tick(pitch: 1.25), 0.28)
        case .toggleOff:
            (tick(pitch: 0.9), 0.28)
        case .pickUp:
            ([
                Voice(from: 440, to: 620, glide: 0.025, attack: 0.002, decay: 0.03),
                Voice(from: 1760, to: 2200, glide: 0.025, level: 0.1, attack: 0.002, decay: 0.008),
            ], 0.22)
        case .drop:
            ([
                Voice(from: 560, to: 330, glide: 0.012, decay: 0.035),
                Voice(from: 2200, to: 1700, level: 0.12, decay: 0.005),
            ], 0.3)
        case .recordStart:
            ([Voice(from: 880, to: 880, attack: 0.003, decay: 0.045)], 0.14)
        case .recorded:
            ([
                Voice(from: 880, to: 880, attack: 0.003, decay: 0.035),
                Voice(delay: 0.07, from: 1318.5, to: 1318.5, attack: 0.003, decay: 0.08),
            ], 0.16)
        case .recordCancel:
            ([Voice(from: 660, to: 600, glide: 0.03, attack: 0.003, decay: 0.04)], 0.13)
        case .recordClear:
            ([
                Voice(from: 1318.5, to: 1318.5, attack: 0.003, decay: 0.035),
                Voice(delay: 0.07, from: 880, to: 880, attack: 0.003, decay: 0.07),
            ], 0.14)
        case .invalid:
            ([
                Voice(from: 240, to: 160, glide: 0.03, attack: 0.002, decay: 0.06),
                Voice(from: 480, to: 320, glide: 0.03, level: 0.3, attack: 0.002, decay: 0.03),
            ], 0.38)
        case .summon:
            ([
                Voice(from: 494, to: 740, glide: 0.04, attack: 0.008, decay: 0.07),
                Voice(from: 988, to: 1480, glide: 0.04, level: 0.15, attack: 0.008, decay: 0.04),
            ], 0.13)
        case .hide:
            ([
                Voice(from: 740, to: 494, glide: 0.04, attack: 0.008, decay: 0.07),
                Voice(from: 1480, to: 988, glide: 0.04, level: 0.15, attack: 0.008, decay: 0.04),
            ], 0.12)
        }
    }

    /// A short, muted knock with a faint bright edge, like a detent.
    private static func tick(pitch: Double) -> [Voice] {
        [
            Voice(from: 480 * pitch, to: 320 * pitch, glide: 0.01, decay: 0.014),
            Voice(from: 2000 * pitch, to: 1700 * pitch, level: 0.15, decay: 0.004),
        ]
    }

    private static func render(_ sound: Sound) -> AVAudioPCMBuffer {
        let (voices, gain) = recipe(for: sound)
        let sampleRate = format.sampleRate
        // Each voice runs until it has faded by about 60 dB.
        let duration = voices.map { $0.delay + $0.attack + $0.decay * 7 }.max() ?? 0
        let frameCount = Int(duration * sampleRate)

        var mix = [Double](repeating: 0, count: frameCount)
        for voice in voices {
            let start = Int(voice.delay * sampleRate)
            var phase = 0.0
            for frame in start..<frameCount {
                let t = Double(frame - start) / sampleRate
                let frequency = voice.to + (voice.from - voice.to) * exp(-t / voice.glide)
                phase += 2 * .pi * frequency / sampleRate
                // A raised-cosine attack avoids the click of starting at full volume.
                let attack = t < voice.attack ? 0.5 - 0.5 * cos(.pi * t / voice.attack) : 1
                let fade = exp(-max(0, t - voice.attack) / voice.decay)
                mix[frame] += voice.level * attack * fade * sin(phase)
            }
        }

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let samples = buffer.floatChannelData![0]
        let peak = mix.map(abs).max() ?? 1
        // The last few milliseconds ramp to exactly zero so the sound never ends on a click.
        let tail = Double(min(frameCount, Int(0.005 * sampleRate)))
        for frame in 0..<frameCount {
            let ramp = min(1, Double(frameCount - frame) / tail)
            samples[frame] = Float(mix[frame] / peak * gain * ramp)
        }
        return buffer
    }
}
