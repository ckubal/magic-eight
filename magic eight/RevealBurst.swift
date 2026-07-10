//
//  RevealBurst.swift
//  magic eight
//
//  A lightweight, theme-flavored particle burst that fires when a fortune is
//  revealed. Purely decorative (no hit testing). Style is chosen per theme.
//

import SwiftUI

enum BurstStyle {
    case confetti   // playful eras — colorful falling confetti
    case spark      // arcade / sport — bright shooting sparks
    case pixel      // retro-tech UIs — little pixel squares
    case magic      // fantasy — soft glowing sparkles
    case sparkle    // classic / vintage — gentle star sparkles

    static func forTheme(_ id: String) -> BurstStyle {
        switch id {
        case "genalpha", "genz", "millennial", "xanga2002", "tiktok2020", "tumblr2012":
            return .confetti
        case "nbajam", "sportscenter", "huntersthompson", "genx":
            return .spark
        case "aimy2k", "facebook2008", "myspace2005", "matrix", "twitterx2024", "deviantart2006":
            return .pixel
        case "shakespearean", "harrypotter":
            return .magic
        default:
            return .sparkle // classic, boomers, fallbacks
        }
    }
}

private struct BurstParticle: Identifiable {
    let id = UUID()
    let angle: Double
    let distance: CGFloat
    let size: CGFloat
    let color: Color
    let spin: Double
    let drift: CGFloat   // extra downward drift (confetti)
    let isSymbol: Bool
    let symbol: String
}

struct RevealBurst: View {
    let style: BurstStyle
    let trigger: Int
    var intense: Bool = false   // shiny → bigger, golden

    @State private var particles: [BurstParticle] = []
    @State private var fired = false

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            ZStack {
                ForEach(particles) { p in
                    shape(for: p)
                        .position(
                            x: cx + (fired ? CGFloat(cos(p.angle)) * p.distance : 0),
                            y: cy + (fired ? CGFloat(sin(p.angle)) * p.distance + p.drift : 0)
                        )
                        .rotationEffect(.degrees(fired ? p.spin : 0))
                        .opacity(fired ? 0 : 1)
                        .scaleEffect(fired ? (style == .spark ? 0.4 : 1.0) : 0.2)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in fire() }
    }

    @ViewBuilder
    private func shape(for p: BurstParticle) -> some View {
        if p.isSymbol {
            Image(systemName: p.symbol)
                .font(.system(size: p.size, weight: .black))
                .foregroundColor(p.color)
                .shadow(color: p.color.opacity(0.6), radius: 4)
        } else if style == .pixel {
            Rectangle().fill(p.color).frame(width: p.size, height: p.size)
        } else if style == .confetti {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(p.color)
                .frame(width: p.size * 0.7, height: p.size * 1.3)
        } else {
            Circle().fill(p.color)
                .frame(width: p.size, height: p.size)
                .shadow(color: p.color.opacity(0.7), radius: 3)
        }
    }

    private func fire() {
        particles = makeParticles()
        fired = false
        // Reset to center on this frame, then animate outward next frame.
        DispatchQueue.main.async {
            let dur = style == .confetti ? 1.3 : 0.9
            withAnimation(.easeOut(duration: dur)) {
                fired = true
            }
        }
    }

    private func makeParticles() -> [BurstParticle] {
        let count = intense ? 34 : (style == .confetti ? 26 : 20)
        let palette = colors()
        return (0..<count).map { i in
            let base = (Double(i) / Double(count)) * 2 * .pi
            let jitter = Double.random(in: -0.35...0.35)
            let dist = CGFloat.random(in: (intense ? 130...260 : 90...200))
            return BurstParticle(
                angle: base + jitter,
                distance: dist,
                size: CGFloat.random(in: (intense ? 10...20 : 7...15)),
                color: palette.randomElement() ?? .white,
                spin: Double.random(in: -220...220),
                drift: style == .confetti ? CGFloat.random(in: 60...160) : 0,
                isSymbol: style == .magic || style == .sparkle,
                symbol: (style == .magic || intense) ? "sparkle" : "star.fill"
            )
        }
    }

    private func colors() -> [Color] {
        if intense {
            return [Color(red: 1, green: 0.84, blue: 0.2), Color(red: 1, green: 0.72, blue: 0.1),
                    .white, Color(red: 1, green: 0.95, blue: 0.6)]
        }
        switch style {
        case .confetti:
            return [.pink, .purple, .cyan, .yellow, .green, .orange, Color(red: 0.4, green: 0.7, blue: 1)]
        case .spark:
            return [Color(red: 1, green: 0.55, blue: 0.1), .yellow, .white, Color(red: 1, green: 0.3, blue: 0.1)]
        case .pixel:
            return [Color(red: 0.3, green: 0.9, blue: 0.5), .white, Color(red: 0.4, green: 0.7, blue: 1), Color(red: 0.6, green: 0.9, blue: 0.7)]
        case .magic:
            return [Color(red: 0.85, green: 0.75, blue: 1), .white, Color(red: 1, green: 0.9, blue: 0.6), Color(red: 0.6, green: 0.8, blue: 1)]
        case .sparkle:
            return [.white, Color(red: 1, green: 0.95, blue: 0.8), Color(red: 0.8, green: 0.9, blue: 1)]
        }
    }
}
