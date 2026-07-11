//
//  SettleItView.swift
//  magic eight
//
//  Phase 6.2 — "settle it": a pass-and-play mode for ending arguments.
//  Choices sit at the top; a wheel-of-fortune spotlight ticks between them
//  (fast → slow), celebrates the winner, then an 8-ball is "thrown" at the
//  screen — growing from tiny to large — with the verdict on it.
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
    @State private var ballScale: CGFloat = 1.0
    @State private var ballOpacity: Double = 1.0
    @State private var winnerPulse = false
    @FocusState private var focusedField: Int?

    private let tick = UIImpactFeedbackGenerator(style: .rigid)

    private var validOptions: [String] {
        options.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var ballAnswer: String {
        if stage == .verdict, let winnerIndex, winnerIndex < validOptions.count {
            return validOptions[winnerIndex]
        }
        return "?"
    }

    var body: some View {
        GeometryReader { geo in
            let ballSize = min(geo.size.width * 0.72, 300)
            ZStack {
                // Keep the theme's colors/vibe, but soften the busy detail and
                // darken enough that the choices and buttons stay readable.
                ThemeWallpaperView(setId: themeSetId)
                    .blur(radius: 7)
                    .ignoresSafeArea()
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.66),
                        Color.black.opacity(0.5),
                        Color.black.opacity(0.68),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    header
                    choicesArea
                    Spacer(minLength: 8)
                    ballView(size: ballSize)
                    Spacer(minLength: 8)
                    bottomControls
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

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                Spacer()
                Text("⚖️ settle it")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Color.clear.frame(width: 34, height: 34)
            }
            if stage == .input {
                Text("can't agree? type the choices — the ball's verdict is final.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Choices (top)

    @ViewBuilder
    private var choicesArea: some View {
        if stage == .input {
            VStack(spacing: 10) {
                ForEach(options.indices, id: \.self) { i in
                    HStack(spacing: 10) {
                        numberBadge(i + 1)
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
                    .background(cardBackground(highlighted: false, winner: false))
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
            }
        } else {
            // Spinner / result board
            VStack(spacing: 10) {
                ForEach(Array(validOptions.enumerated()), id: \.offset) { i, option in
                    let isHighlighted = (stage == .deciding && i == spotlight)
                    let isWinner = (i == winnerIndex)
                    HStack(spacing: 10) {
                        numberBadge(i + 1, lit: isHighlighted || isWinner)
                        Text(option)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(isHighlighted || isWinner ? .black : .white.opacity(0.85))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(cardBackground(highlighted: isHighlighted, winner: isWinner))
                    .scaleEffect(isWinner && winnerPulse ? 1.05 : (isHighlighted ? 1.02 : 1.0))
                    .animation(.easeOut(duration: 0.09), value: spotlight)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: winnerPulse)
                }
            }
        }
    }

    private func numberBadge(_ n: Int, lit: Bool = false) -> some View {
        ZStack {
            Circle().fill(lit ? Color.black.opacity(0.25) : Color.white.opacity(0.16))
                .frame(width: 30, height: 30)
            Text("\(n)")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(lit ? .black : .white)
        }
    }

    private func cardBackground(highlighted: Bool, winner: Bool) -> some View {
        Capsule()
            .fill(winner || highlighted
                  ? Color(red: 1.0, green: 0.9, blue: 0.55)
                  : Color.black.opacity(0.4))
            .overlay(
                Capsule().stroke(
                    winner ? Color(red: 1.0, green: 0.85, blue: 0.3) : Color.white.opacity(0.22),
                    lineWidth: winner ? 2 : 1
                )
            )
    }

    // MARK: - The ball

    private func ballView(size: CGFloat) -> some View {
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
                .shadow(color: .black.opacity(0.55), radius: 26, x: 0, y: 14)

            if stage == .verdict {
                TriangleWindow(size: tri, offset: .zero) {
                    TriangleFittedText(text: ballAnswer.uppercased(), opacity: 1)
                }
            } else if stage == .input {
                Text("?")
                    .font(.system(size: size * 0.26, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(ballScale)
        .opacity(ballOpacity)
    }

    // MARK: - Bottom controls

    @ViewBuilder
    private var bottomControls: some View {
        switch stage {
        case .input:
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
        case .deciding:
            Text("the ball is deciding…")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
        case .verdict:
            HStack(spacing: 12) {
                pillButton("go again", icon: "arrow.clockwise") { startDeciding() }
                pillButton("new choices", icon: "pencil") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        stage = .input
                        winnerIndex = nil
                        ballScale = 1.0
                        ballOpacity = 1.0
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
                    .fill(Color.black.opacity(0.5))
                    .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
            )
        }
    }

    // MARK: - The decision

    private func startDeciding() {
        let opts = validOptions
        guard opts.count >= 2 else { return }
        let n = opts.count
        focusedField = nil
        winnerIndex = nil
        winnerPulse = false
        spotlight = 0

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { stage = .deciding }
        // The ball steps aside while the wheel spins.
        withAnimation(.easeOut(duration: 0.3)) { ballOpacity = 0 }

        // Land on a random winner after a satisfying wheel-of-fortune spin.
        let winner = Int.random(in: 0..<n)
        let baseSteps = 18
        let extra = ((winner - baseSteps) % n + n) % n
        let totalSteps = baseSteps + extra

        var clock = 0.15
        for i in 0..<totalSteps {
            let progress = Double(i) / Double(max(1, totalSteps - 1))
            let interval = 0.045 + 0.42 * pow(progress, 2.6)   // fast → slow
            clock += interval
            let isLast = i == totalSteps - 1
            DispatchQueue.main.asyncAfter(deadline: .now() + clock) {
                guard stage == .deciding else { return }
                spotlight = (spotlight + 1) % n
                tick.impactOccurred(intensity: isLast ? 1.0 : 0.55)
                if isLast { landOn(winner: spotlight) }
            }
        }
    }

    private func landOn(winner: Int) {
        winnerIndex = winner
        // Celebrate the winning choice card.
        withAnimation { winnerPulse = true }
        burstTrigger += 1
        haptics.play(for: themeSetId)
        if soundEnabled { sound.play(for: themeSetId) }

        // Then throw the 8-ball at the screen with the verdict on it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            guard stage == .deciding else { return }
            ballScale = 0.06
            ballOpacity = 1.0
            stage = .verdict
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) {
                ballScale = 1.18
            }
            burstTrigger += 1
            haptics.playShiny()
            if soundEnabled { sound.playShiny() }
        }
    }
}
