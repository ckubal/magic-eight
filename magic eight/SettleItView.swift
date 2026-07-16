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
    let haptics: HapticManager
    @ObservedObject var motionManager: MotionManager
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
    // Tally of wins per choice across "go again" rounds (same choices).
    @State private var winCounts: [String: Int] = [:]
    // After the first run, a sustained shake re-rolls.
    @State private var canShakeRerun = false
    @State private var shakeAccum: Double = 0
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

    /// Choices with their win tallies, best first.
    private var leaderboard: [(name: String, wins: Int)] {
        validOptions.map { ($0, winCounts[$0] ?? 0) }.sorted { $0.1 > $1.1 }
    }

    private var gamesPlayed: Int { winCounts.values.reduce(0, +) }

    /// Escalating "best of" suggestion. Leader has n wins → offer to play a
    /// best-of-(2n+1), which is clinched at n+1 wins.
    private var seriesPrompt: String? {
        guard gamesPlayed >= 1 else { return nil }
        let n = winCounts.values.max() ?? 0
        return "best \(n + 1) of \(2 * n + 1)?"
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
            .onReceive(motionManager.throttledShakeIntensity) { intensity in
                // Re-roll only on a *sustained*, vigorous shake — never on a
                // single bump or lifting the phone. Accumulate ~0.05s per tick
                // while shaking hard; a stop decays it fast.
                guard canShakeRerun, validOptions.count >= 2 else {
                    shakeAccum = 0
                    return
                }
                if intensity > 0.8 {
                    shakeAccum += 0.05
                    if shakeAccum >= 0.75 {   // ~0.75s of real shaking
                        shakeAccum = 0
                        startDeciding()
                    }
                } else {
                    shakeAccum *= 0.5
                }
            }
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
                        Spacer(minLength: 6)
                        Text(option.lowercased())
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(isHighlighted || isWinner ? .black : .white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 6)
                        // Balance the number badge so the label is truly centered.
                        Color.clear.frame(width: 30, height: 1)
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
            Circle().fill(lit ? Color.white.opacity(0.92) : Color.white.opacity(0.16))
                .frame(width: 30, height: 30)
            Text("\(n)")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(lit ? .black : .white)
        }
    }

    // 90s-arcade celebratory palette for the highlighted / winning choice.
    private func cardFill(highlighted: Bool, winner: Bool) -> AnyShapeStyle {
        if winner {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.22, blue: 0.62),  // hot pink
                        Color(red: 1.0, green: 0.48, blue: 0.14),  // tangerine
                        Color(red: 1.0, green: 0.82, blue: 0.18),  // gold
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
        } else if highlighted {
            return AnyShapeStyle(Color(red: 0.0, green: 0.85, blue: 0.85))  // electric cyan flash
        } else {
            return AnyShapeStyle(Color.black.opacity(0.4))
        }
    }

    private func cardBackground(highlighted: Bool, winner: Bool) -> some View {
        Capsule()
            .fill(cardFill(highlighted: highlighted, winner: winner))
            .overlay(
                Capsule().stroke(
                    winner ? Color(red: 1.0, green: 0.95, blue: 0.6) : Color.white.opacity(0.22),
                    lineWidth: winner ? 2.5 : 1
                )
            )
            .shadow(
                color: winner ? Color(red: 1.0, green: 0.25, blue: 0.6).opacity(0.7) : .clear,
                radius: winner ? 16 : 0
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
                    // The verdict on the ball stays uppercase, like the classic die.
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
            VStack(spacing: 12) {
                if gamesPlayed >= 1 {
                    leaderboardView
                }
                if let prompt = seriesPrompt {
                    Text("🏆 \(prompt)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 1.0, green: 0.9, blue: 0.55))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                }
                HStack(spacing: 12) {
                    pillButton("go again", icon: "arrow.clockwise") { startDeciding() }
                    pillButton("new choices", icon: "pencil") {
                        winCounts = [:]
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            stage = .input
                            winnerIndex = nil
                            ballScale = 1.0
                            ballOpacity = 1.0
                        }
                    }
                }

                Text("🎲 or shake to go again")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var leaderboardView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(leaderboard.enumerated()), id: \.offset) { idx, entry in
                    HStack(spacing: 5) {
                        if idx == 0 && entry.wins > 0 { Text("👑").font(.system(size: 12)) }
                        Text(entry.name.lowercased())
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 130, alignment: .leading)
                        Text("\(entry.wins)")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.35))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.5))
                            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    )
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity)
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
        canShakeRerun = false
        shakeAccum = 0
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
        if winner < validOptions.count {
            winCounts[validOptions[winner], default: 0] += 1
        }
        // Celebrate the winning choice card.
        withAnimation { winnerPulse = true }
        burstTrigger += 1
        haptics.play(for: themeSetId)

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
            // Arm shake-to-rerun once the verdict has settled.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if stage == .verdict { canShakeRerun = true }
            }
        }
    }
}
