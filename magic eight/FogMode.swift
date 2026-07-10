//
//  FogMode.swift
//  magic eight
//
//  Phase 6.5 — fog mode (opt-in, Settings). Blow on the phone and the glass
//  fogs up like breath on a cold window; rub the screen to wipe it clear.
//  The mic is only monitored while the mode is enabled, and audio is never
//  recorded or stored — we only read the input level.
//

import AVFoundation
import SwiftUI
import UIKit

// MARK: - Blow detection

final class BlowDetector {
    private let engine = AVAudioEngine()
    private var running = false
    private var hotBuffers = 0
    private var cooldownUntil = Date.distantPast

    /// Fired on the main thread when a sustained blow is detected.
    var onBlow: (() -> Void)?

    func start() {
        guard !running else { return }
        guard AVAudioApplication.shared.recordPermission == .granted else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.mixWithOthers, .defaultToSpeaker]
        )
        try? session.setActive(true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { return }

        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.process(buffer)
        }

        do {
            try engine.start()
            running = true
        } catch {
            input.removeTap(onBus: 0)
        }
    }

    func stop() {
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running = false
        hotBuffers = 0
        // Hand the session back to gentle playback behavior.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }

        var sum: Float = 0
        for i in 0..<n { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(n))

        // A blow is loud, broadband, and sustained — a few consecutive hot
        // buffers filters out taps and speech spikes.
        if rms > 0.14 {
            hotBuffers += 1
        } else {
            hotBuffers = max(0, hotBuffers - 1)
        }

        if hotBuffers >= 4, Date() > cooldownUntil {
            hotBuffers = 0
            cooldownUntil = Date().addingTimeInterval(3.0)
            DispatchQueue.main.async { [weak self] in
                self?.onBlow?()
            }
        }
    }
}

// MARK: - The fog itself

struct FogOverlay: View {
    @Binding var fogAmount: Double        // 0 = clear, 1 = fully fogged
    @Binding var wipes: [CGPoint]         // finger path — erased areas

    private let wiper = UIImpactFeedbackGenerator(style: .soft)

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                ctx.opacity = fogAmount
                // Condensation: a soft white sheet, denser toward the middle.
                ctx.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color.white.opacity(0.78),
                            Color.white.opacity(0.62),
                            Color.white.opacity(0.5),
                        ]),
                        center: CGPoint(x: size.width / 2, y: size.height / 2),
                        startRadius: 0,
                        endRadius: max(size.width, size.height) * 0.75
                    )
                )
                // Wipe strokes: soft-edged erases along the finger path.
                ctx.blendMode = .destinationOut
                for p in wipes {
                    for (r, a) in [(34.0, 1.0), (46.0, 0.5), (58.0, 0.25)] {
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                            with: .color(.white.opacity(a))
                        )
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard fogAmount > 0.05 else { return }
                        if let last = wipes.last {
                            let dx = value.location.x - last.x
                            let dy = value.location.y - last.y
                            guard dx * dx + dy * dy > 144 else { return } // every ~12pt
                        }
                        wipes.append(value.location)
                        if wipes.count % 4 == 0 {
                            wiper.impactOccurred(intensity: 0.35)
                        }
                    }
            )
        }
        .ignoresSafeArea()
    }
}
