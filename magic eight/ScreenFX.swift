//
//  ScreenFX.swift
//  magic eight
//
//  Phase 6.4 — era-authentic screen treatments. Light-touch overlays
//  (tiled tiles + vignette) so each retro era feels like it's playing on
//  period-correct hardware. Kept subtle so the answer text stays legible;
//  toggleable in Settings ("retro screen effects").
//

import SwiftUI
import UIKit

enum ScreenFX {
    case crt      // scanlines + vignette (old TV / arcade monitor)
    case vhs      // living film grain + faint color fringe (tape era)
    case lcd      // pixel grid (early desktop / handheld LCD)
    case none

    static func forTheme(_ id: String) -> ScreenFX {
        switch id {
        case "matrix", "nbajam", "sportscenter", "boomers1958":
            return .crt
        case "genx", "tumblr2012", "huntersthompson":
            return .vhs
        case "aimy2k", "xanga2002":
            return .lcd
        default:
            return .none
        }
    }
}

struct ScreenFXOverlay: View {
    let fx: ScreenFX
    @State private var flicker = false

    var body: some View {
        ZStack {
            switch fx {
            case .crt:
                tiled("fx-scanline")
                    .opacity(0.55)
                // Soft CRT vignette
                RadialGradient(
                    colors: [.clear, .clear, Color.black.opacity(0.28)],
                    center: .center,
                    startRadius: 0,
                    endRadius: UIScreen.screenRadius
                )
            case .vhs:
                tiled("fx-grain")
                    .opacity(flicker ? 0.5 : 0.85)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) {
                            flicker = true
                        }
                    }
                // Faint magenta/cyan fringe at the edges (tape color bleed)
                LinearGradient(
                    colors: [Color(red: 1, green: 0, blue: 0.6).opacity(0.05),
                             .clear, .clear, .clear,
                             Color(red: 0, green: 0.9, blue: 1).opacity(0.05)],
                    startPoint: .leading, endPoint: .trailing
                )
            case .lcd:
                tiled("fx-lcd")
                    .opacity(0.5)
            case .none:
                EmptyView()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func tiled(_ name: String) -> some View {
        if let ui = UIImage(named: name) {
            Image(uiImage: ui)
                .resizable(resizingMode: .tile)
        }
    }
}

private extension UIScreen {
    /// Rough corner-to-center distance of the largest current screen.
    static var screenRadius: CGFloat {
        let size = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds.size ?? CGSize(width: 430, height: 932)
        return sqrt(size.width * size.width + size.height * size.height) / 2
    }
}
