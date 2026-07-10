//
//  BallSkins.swift
//  magic eight
//
//  Phase 6.3 — collectible ball skins. All drawn in code (no assets).
//  Some unlock by finding rare shiny fortunes, pairing with shinyCount.
//

import SwiftUI

enum BallSkin: String, CaseIterable, Identifiable {
    case classic
    case crystal
    case chrome
    case glitter
    case lava

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "classic"
        case .crystal: return "crystal"
        case .chrome: return "chrome"
        case .glitter: return "disco"
        case .lava: return "lava"
        }
    }

    /// Shiny fortunes required to unlock.
    var requiredShinies: Int {
        switch self {
        case .classic, .crystal: return 0
        case .chrome: return 1
        case .glitter: return 3
        case .lava: return 5
        }
    }

    func isUnlocked(shinyCount: Int) -> Bool {
        shinyCount >= requiredShinies
    }

    static var current: BallSkin {
        BallSkin(rawValue: UserDefaults.standard.string(forKey: "ballSkin") ?? "classic") ?? .classic
    }

    // MARK: - Rendering

    /// The sphere's base fill + skin-specific decoration, sized to the ball.
    @ViewBuilder
    func sphere(size: CGFloat) -> some View {
        switch self {
        case .classic:
            Circle().fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.15, green: 0.15, blue: 0.35),
                        Color(red: 0.08, green: 0.08, blue: 0.2),
                        Color(red: 0.02, green: 0.02, blue: 0.08),
                        .black,
                    ]),
                    center: UnitPoint(x: 0.3, y: 0.3),
                    startRadius: size * 0.2,
                    endRadius: size * 0.9
                )
            )

        case .crystal:
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.75, green: 0.9, blue: 1.0).opacity(0.85),
                            Color(red: 0.45, green: 0.65, blue: 0.9).opacity(0.8),
                            Color(red: 0.2, green: 0.3, blue: 0.55),
                            Color(red: 0.08, green: 0.12, blue: 0.3),
                        ]),
                        center: UnitPoint(x: 0.32, y: 0.28),
                        startRadius: size * 0.05,
                        endRadius: size * 0.95
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                        .blur(radius: 0.5)
                )

        case .chrome:
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(white: 0.95), location: 0.0),
                            .init(color: Color(white: 0.55), location: 0.28),
                            .init(color: Color(white: 0.15), location: 0.52),
                            .init(color: Color(white: 0.65), location: 0.75),
                            .init(color: Color(white: 0.3), location: 1.0),
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // Horizon band, mirror-ball style
                    Rectangle()
                        .fill(Color.white.opacity(0.35))
                        .frame(height: size * 0.05)
                        .blur(radius: size * 0.02)
                        .offset(y: size * 0.08)
                        .clipShape(Circle())
                )

        case .glitter:
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.35, green: 0.12, blue: 0.5),
                            Color(red: 0.2, green: 0.05, blue: 0.35),
                            Color(red: 0.08, green: 0.02, blue: 0.18),
                        ]),
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: size * 0.1,
                        endRadius: size * 0.9
                    )
                )
                .overlay(sparkles(size: size).clipShape(Circle()))

        case .lava:
            Circle().fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(red: 1.0, green: 0.75, blue: 0.25),
                        Color(red: 0.95, green: 0.4, blue: 0.1),
                        Color(red: 0.6, green: 0.1, blue: 0.05),
                        Color(red: 0.2, green: 0.02, blue: 0.02),
                    ]),
                    center: UnitPoint(x: 0.32, y: 0.3),
                    startRadius: size * 0.08,
                    endRadius: size * 0.95
                )
            )
        }
    }

    /// Deterministic sparkle field for the disco skin (stable across renders).
    private func sparkles(size: CGFloat) -> some View {
        Canvas { context, canvasSize in
            var seed: UInt64 = 0x8BA11
            func rand() -> CGFloat {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat(seed >> 33) / CGFloat(UInt32.max)
            }
            for _ in 0..<46 {
                let x = rand() * canvasSize.width
                let y = rand() * canvasSize.height
                let r = 0.8 + rand() * 2.2
                let hue = rand()
                let color = Color(hue: hue, saturation: 0.35, brightness: 1.0)
                    .opacity(0.35 + Double(rand()) * 0.55)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                    with: .color(color)
                )
            }
        }
        .frame(width: size, height: size)
    }
}
