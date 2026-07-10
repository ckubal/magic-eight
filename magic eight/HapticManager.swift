//
//  HapticManager.swift
//  magic eight
//
//  Per-era haptic "signatures" played when a fortune is revealed, plus a
//  celebratory pattern for rare "shiny" answers. Uses CoreHaptics where
//  available and falls back to UIKit feedback generators otherwise
//  (simulator, older hardware).
//

import UIKit
import CoreHaptics

/// The distinct feels a theme can map to. Kept small on purpose — a handful of
/// well-tuned patterns grouped by vibe reads better than 20 mushy ones.
enum HapticSignature {
    case thunk      // one firm impact — classic / retro / broadcast
    case staccato   // crisp digital taps — typing, dial-up, feeds
    case boom       // explosive hit + rumble — arcade / gonzo / grunge
    case sparkle    // light ascending shimmer — kidcore / neon / y2k
    case mystic     // soft swell then tap — parchment / magical
}

final class HapticManager {
    private var engine: CHHapticEngine?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    // UIKit fallbacks for when CoreHaptics isn't available.
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let notify = UINotificationFeedbackGenerator()

    init() {
        prepareEngine()
    }

    /// Maps a theme id to its haptic signature.
    static func signature(for themeId: String) -> HapticSignature {
        switch themeId {
        case "matrix", "aimy2k", "facebook2008", "twitterx2024", "deviantart2006", "xanga2002":
            return .staccato
        case "nbajam", "genx", "huntersthompson":
            return .boom
        case "genalpha", "genz", "millennial", "tiktok2020", "myspace2005", "tumblr2012":
            return .sparkle
        case "shakespearean", "harrypotter":
            return .mystic
        default: // classic, boomers1958, sportscenter, random...
            return .thunk
        }
    }

    // MARK: - Public

    func prepare() {
        impact.prepare()
        notify.prepare()
        restartEngineIfNeeded()
    }

    func play(for themeId: String) {
        play(signature: HapticManager.signature(for: themeId))
    }

    func play(signature: HapticSignature) {
        guard supportsHaptics, let engine else {
            playFallback(signature); return
        }
        do {
            let pattern = try CHHapticPattern(events: events(for: signature), parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            playFallback(signature)
        }
    }

    /// Big celebratory buzz for a rare shiny fortune.
    func playShiny() {
        guard supportsHaptics, let engine else {
            notify.notificationOccurred(.success); return
        }
        do {
            let pattern = try CHHapticPattern(events: shinyEvents(), parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            notify.notificationOccurred(.success)
        }
    }

    // MARK: - Engine lifecycle

    private func prepareEngine() {
        guard supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.isAutoShutdownEnabled = true
            engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
            engine?.stoppedHandler = { _ in }
            try engine?.start()
        } catch {
            engine = nil
        }
    }

    private func restartEngineIfNeeded() {
        guard supportsHaptics else { return }
        if engine == nil { prepareEngine() } else { try? engine?.start() }
    }

    // MARK: - Patterns

    private func transient(_ time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: time
        )
    }

    private func continuous(_ time: TimeInterval, duration: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: time,
            duration: duration
        )
    }

    private func events(for signature: HapticSignature) -> [CHHapticEvent] {
        switch signature {
        case .thunk:
            return [transient(0, intensity: 1.0, sharpness: 0.5)]
        case .staccato:
            return (0..<4).map { i in
                transient(Double(i) * 0.06, intensity: 0.55, sharpness: 0.95)
            }
        case .boom:
            return [
                transient(0, intensity: 1.0, sharpness: 0.25),
                continuous(0.02, duration: 0.35, intensity: 0.65, sharpness: 0.1)
            ]
        case .sparkle:
            return (0..<5).map { i in
                transient(Double(i) * 0.05,
                          intensity: Float(0.35 + Double(i) * 0.05),
                          sharpness: Float(0.4 + Double(i) * 0.14))
            }
        case .mystic:
            return [
                continuous(0, duration: 0.4, intensity: 0.4, sharpness: 0.2),
                transient(0.4, intensity: 0.75, sharpness: 0.4)
            ]
        }
    }

    private func shinyEvents() -> [CHHapticEvent] {
        // Rising shimmer that lands on a satisfying boom.
        var events: [CHHapticEvent] = (0..<8).map { i in
            transient(Double(i) * 0.045,
                      intensity: Float(0.4 + Double(i) * 0.06),
                      sharpness: Float(0.5 + Double(i) * 0.06))
        }
        events.append(transient(0.42, intensity: 1.0, sharpness: 0.3))
        events.append(continuous(0.44, duration: 0.3, intensity: 0.7, sharpness: 0.15))
        return events
    }

    private func playFallback(_ signature: HapticSignature) {
        switch signature {
        case .thunk: impact.impactOccurred(intensity: 1.0)
        case .boom: impact.impactOccurred(intensity: 1.0)
        case .staccato:
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) {
                    self.impact.impactOccurred(intensity: 0.5)
                }
            }
        case .sparkle: notify.notificationOccurred(.success)
        case .mystic: impact.impactOccurred(intensity: 0.6)
        }
    }
}
