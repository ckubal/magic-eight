//
//  SettleItView.swift
//  magic eight
//
//  Phase 6.2 — "settle it": a separate pass-and-play mode for ending
//  arguments. Add 2–4 options, the ball spins through them slot-machine
//  style, and delivers a final verdict. Tap-driven (no flipping needed).
//

import SwiftUI
import UIKit

struct SettleItView: View {
    let themeSetId: String
    let soundEnabled: Bool
    let sound: SoundManager
    let haptics: HapticManager
    let onClose: () -> Void

    private enum Stage {
        case input
        case deciding
        case verdict
    }

    @State private var stage: Stage = .input
    @State private var options: [String] = ["", ""]
    @State private var spotlight: Int = 0          // option currently lit while deciding
    @State private var winnerIndex: Int?
    @State private var burstTrigger = 0
    @FocusState private var focusedField: Int?

    private let tick = UIImpactFeedbackGenerator(style: .rigid)

    private var validOptions: [String] {
        options.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        ZStack {
            ThemeWallpaperView(setId: themeSetId)
                .ignoresSafeArea()
            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.75)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                header

                switch stage {
                case .input: inputStage
                case .deciding: decidingStage
                case .verdict: verdictStage
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)

            RevealBurst(style: .confetti, trigger: burstTrigger, intense: true)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onTapGesture { focusedField = nil }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
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
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundColor(.white)

            if stage == .input {
                Text("can't agree? type the choices.\nthe ball decides — its verdict is final.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Input

    private var inputStage: some View {
        VStack(spacing: 12) {
            ForEach(options.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    TextField("option \(i + 1)  (e.g. pizza)", text: $options[i])
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .focused($focusedField, equals: i)
                        .submitLabel(i == options.count - 1 ? .done : .next)
                        .onSubmit {
                            focusedField = i < options.count - 1 ? i + 1 : nil
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        )

                    if options.count > 2 {
                        Button(action: { options.remove(at: i) }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }
                }
            }

            if options.count < 4 {
                Button(action: {
                    options.append("")
                    focusedField = options.count - 1
                }) {
                    Label("add option", systemImage: "plus.circle.fill")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 2)
            }

            Button(action: startDeciding) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                    Text("let the ball decide")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                    Image(systemName: "sparkles")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 26)
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
            .padding(.top, 14)
        }
    }

    // MARK: - Deciding (slot machine)

    private var decidingStage: some View {
        VStack(spacing: 18) {
            Text("the ball is thinking…")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 8)

            optionBoard(highlight: spotlight, dimOthers: true)
        }
    }

    // MARK: - Verdict

    private var verdictStage: some View {
        VStack(spacing: 20) {
            Text("the ball has decided")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
                .padding(.top, 6)

            if let winnerIndex, winnerIndex < validOptions.count {
                Text(validOptions[winnerIndex])
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 1.0, green: 0.9, blue: 0.55))
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)
                    .padding(.horizontal, 12)
                    .transition(.scale.combined(with: .opacity))
            }

            Text("this verdict is final. no take-backs.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            HStack(spacing: 12) {
                pillButton("go again", icon: "arrow.clockwise") {
                    startDeciding()
                }
                pillButton("new choices", icon: "pencil") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        stage = .input
                        winnerIndex = nil
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private func pillButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
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

    // MARK: - Option board

    private func optionBoard(highlight: Int, dimOthers: Bool) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(validOptions.enumerated()), id: \.offset) { i, option in
                Text(option)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(i == highlight ? .black : .white.opacity(dimOthers ? 0.45 : 0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(i == highlight
                                  ? Color(red: 1.0, green: 0.9, blue: 0.55)
                                  : Color.white.opacity(0.1))
                    )
                    .scaleEffect(i == highlight ? 1.04 : 1.0)
                    .animation(.easeOut(duration: 0.1), value: highlight)
            }
        }
    }

    // MARK: - The decision

    private func startDeciding() {
        let opts = validOptions
        guard opts.count >= 2 else { return }
        focusedField = nil
        winnerIndex = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            stage = .deciding
        }

        // Pick the winner up front, then spin so the spotlight lands on it.
        let winner = Int.random(in: 0..<opts.count)
        // Accelerating-then-decelerating tick intervals (slot machine feel).
        var intervals: [Double] = Array(repeating: 0.09, count: opts.count * 2)
        var step = 0.12
        while step < 0.55 {
            intervals.append(step)
            step *= 1.35
        }
        // Pad so the final tick lands exactly on the winner.
        let landing = (spotlight + intervals.count) % opts.count
        let extra = (winner - landing + opts.count) % opts.count
        intervals.append(contentsOf: Array(repeating: 0.55, count: extra).map { _ in 0.5 })

        var delay = 0.15
        for (i, interval) in intervals.enumerated() {
            delay += interval
            let isLast = i == intervals.count - 1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard stage == .deciding else { return }
                spotlight = (spotlight + 1) % opts.count
                tick.impactOccurred(intensity: isLast ? 1.0 : 0.6)
                if isLast {
                    finishDeciding(winner: spotlight)
                }
            }
        }
    }

    private func finishDeciding(winner: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard stage == .deciding else { return }
            winnerIndex = winner
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                stage = .verdict
            }
            burstTrigger += 1
            haptics.playShiny()
            if soundEnabled { sound.playShiny() }
        }
    }
}
