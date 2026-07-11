//
//  SettleItView.swift
//  magic eight
//
//  Phase 6.2 — "settle it": a pass-and-play mode for ending arguments.
//  Type 2–4 choices; the magic 8-ball itself spins through them slot-machine
//  style inside its triangle window and lands on a verdict. Tap-driven.
//

import SwiftUI
import UIKit

struct SettleItView: View {
    let themeSetId: String
    let soundEnabled: Bool
    let sound: SoundManager
    let haptics: HapticManager
    let onClose: () -> Void

    private enum Stage { case input, deciding, verdict }

    @State private var stage: Stage = .input
    @State private var options: [String] = ["", ""]
    @State private var spotlight = 0
    @State private var winnerIndex: Int?
    @State private var burstTrigger = 0
    @State private var ballWobble = false
    @FocusState private var focusedField: Int?

    private let tick = UIImpactFeedbackGenerator(style: .rigid)

    private var validOptions: [String] {
        options.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// What the ball's triangle currently reads.
    private var triangleText: String {
        switch stage {
        case .input:
            return "?"
        case .deciding:
            let opts = validOptions
            return opts.isEmpty ? "?" : opts[spotlight % opts.count]
        case .verdict:
            if let winnerIndex, winnerIndex < validOptions.count { return validOptions[winnerIndex] }
            return "?"
        }
    }

    var body: some View {
        GeometryReader { geo in
            let ballSize = min(geo.size.width * 0.62, 240)
            ZStack {
                // Deep 8-ball-colored backdrop — cohesive and readable, with a
                // faint, heavily darkened wash of the current theme for flavor.
                Color.black.ignoresSafeArea()
                ThemeWallpaperView(setId: themeSetId)
                    .blur(radius: 40)
                    .opacity(0.18)
                    .ignoresSafeArea()
                RadialGradient(
                    colors: [
                        Color(red: 0.10, green: 0.10, blue: 0.26),
                        Color(red: 0.03, green: 0.03, blue: 0.10),
                        .black,
                    ],
                    center: .center,
                    startRadius: 30,
                    endRadius: 620
                )
                .opacity(0.94)
                .ignoresSafeArea()

                VStack(spacing: 18) {
                    header

                    eightBall(size: ballSize)
                        .padding(.vertical, stage == .input ? 2 : 8)

                    Group {
                        switch stage {
                        case .input: inputStage
                        case .deciding: decidingStage
                        case .verdict: verdictStage
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                RevealBurst(style: .confetti, trigger: burstTrigger, intense: true)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture { focusedField = nil }
        }
    }

    // MARK: - The 8-ball

    private func eightBall(size: CGFloat) -> some View {
        let tri = size * 0.5
        return ZStack {
            BallSkin.classic.sphere(size: size)
                .overlay(
                    Circle().fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.14), .clear],
                            center: UnitPoint(x: 0.32, y: 0.28),
                            startRadius: size * 0.04,
                            endRadius: size * 0.5
                        )
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.5), radius: 22, x: 0, y: 12)

            if stage != .input {
                TriangleWindow(size: tri, offset: .zero) {
                    TriangleFittedText(text: triangleText.uppercased(), opacity: 1)
                }
            } else {
                Text("?")
                    .font(.system(size: size * 0.28, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(ballWobble ? 2.5 : -2.5))
        .animation(
            stage == .deciding
                ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true)
                : .default,
            value: ballWobble
        )
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.black.opacity(0.45)))
                }
                Spacer()
            }

            Text("⚖️ settle it")
                .font(.system(size: stage == .input ? 30 : 24, weight: .black, design: .rounded))
                .foregroundColor(.white)

            if stage == .input {
                Text("can't agree? type the choices —\nthe ball's verdict is final.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Input

    private var inputStage: some View {
        VStack(spacing: 10) {
            ForEach(options.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.16)).frame(width: 30, height: 30)
                        Text("\(i + 1)")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    TextField("", text: $options[i], prompt:
                        Text(i == 0 ? "e.g. pizza" : (i == 1 ? "e.g. tacos" : "another option"))
                            .foregroundColor(.white.opacity(0.4))
                    )
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .focused($focusedField, equals: i)
                    .submitLabel(i == options.count - 1 ? .done : .next)
                    .onSubmit { focusedField = i < options.count - 1 ? i + 1 : nil }

                    if options.count > 2 {
                        Button(action: { options.remove(at: i) }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
                )
            }

            if options.count < 4 {
                Button(action: {
                    options.append("")
                    focusedField = options.count - 1
                }) {
                    Label("add option", systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 2)
            }

            Button(action: startDeciding) {
                Text("ask the ball")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: validOptions.count >= 2
                                    ? [Color(red: 0.95, green: 0.3, blue: 0.5), Color(red: 1.0, green: 0.6, blue: 0.2)]
                                    : [Color.gray.opacity(0.5), Color.gray.opacity(0.4)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    )
            }
            .disabled(validOptions.count < 2)
            .padding(.top, 10)
        }
    }

    // MARK: - Deciding / verdict captions

    private var decidingStage: some View {
        Text("the ball is deciding…")
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.75))
    }

    private var verdictStage: some View {
        VStack(spacing: 16) {
            Text("the ball has spoken. it's final.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))

            HStack(spacing: 12) {
                pillButton("go again", icon: "arrow.clockwise") { startDeciding() }
                pillButton("new choices", icon: "pencil") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        stage = .input
                        winnerIndex = nil
                    }
                }
            }
        }
    }

    private func pillButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold))
                Text(title).font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.92))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.45))
                    .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
            )
        }
    }

    // MARK: - The decision (slot machine)

    private func startDeciding() {
        let opts = validOptions
        guard opts.count >= 2 else { return }
        let n = opts.count
        focusedField = nil
        winnerIndex = nil
        spotlight = 0
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { stage = .deciding }
        ballWobble = true

        // Pick the winner, then spin enough whole loops to land on it.
        let winner = Int.random(in: 0..<n)
        let minSteps = n * 3
        let extra = ((winner - (spotlight + minSteps)) % n + n) % n
        let totalSteps = minSteps + extra

        // Accelerate-then-decelerate tick intervals.
        var clock = 0.15
        for i in 0..<totalSteps {
            let progress = Double(i) / Double(max(1, totalSteps - 1))
            let interval = 0.05 + 0.34 * pow(progress, 2.3)   // fast → slow
            clock += interval
            let isLast = i == totalSteps - 1
            DispatchQueue.main.asyncAfter(deadline: .now() + clock) {
                guard stage == .deciding else { return }
                spotlight = (spotlight + 1) % n
                tick.impactOccurred(intensity: isLast ? 1.0 : 0.55)
                if isLast { finishDeciding(winner: spotlight) }
            }
        }
    }

    private func finishDeciding(winner: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            guard stage == .deciding else { return }
            ballWobble = false
            winnerIndex = winner
            withAnimation(.spring(response: 0.5, dampingFraction: 0.68)) { stage = .verdict }
            burstTrigger += 1
            haptics.playShiny()
            if soundEnabled { sound.playShiny() }
        }
    }
}
