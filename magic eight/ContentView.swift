//
//  ContentView.swift
//  magic eight
//
//  Created by Charlie Kubal on 12/1/25.
//

import SwiftUI
import Combine
import UIKit

enum AppState {
    case waiting
    case faceDown
    case loading
    case showingResponse
}

/// Pure SwiftUI text renderer with UIFont-measured binary-search font fitting.
/// This guarantees the rendered text always fits inside its provided frame.
struct TriangleFittedText: View {
    let text: String
    let opacity: Double
    let minFontSize: CGFloat = 7
    let maxFontSize: CGFloat = 34
    let lineSpacing: CGFloat = 2
    
    @State private var fittedFontSize: CGFloat = 16
    @State private var wrappedText: String = ""
    @State private var lineCount: Int = 1
    
    var body: some View {
        GeometryReader { geometry in
            Text(wrappedText.isEmpty ? text : wrappedText)
                .font(.system(size: fittedFontSize, weight: .semibold, design: .default))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(lineSpacing)
                .lineLimit(nil)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                .padding(.top, lineCount <= 2 ? fittedFontSize * 0.8 : 0)
                .clipped()
                .allowsTightening(false)
                .opacity(opacity)
                .shadow(color: .black.opacity(0.55), radius: 2, x: 0, y: 1)
                .shadow(color: .white.opacity(0.15), radius: 3, x: 0, y: 0)
                .onAppear {
                    recalculateLayout(for: geometry.size)
                }
                .onChange(of: text) {
                    recalculateLayout(for: geometry.size)
                }
                .onChange(of: geometry.size) { _, newSize in
                    recalculateLayout(for: newSize)
                }
        }
    }
    
    private func recalculateLayout(for size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        
        var lo = minFontSize
        var hi = maxFontSize
        var best = minFontSize
        var bestWrapped = text
        
        for _ in 0..<18 {
            let mid = (lo + hi) / 2
            guard let candidateWrapped = wrapTextWithoutBreakingWords(text, fontSize: mid, width: size.width) else {
                hi = mid
                if hi - lo < 0.25 { break }
                continue
            }
            
            if textFits(candidateWrapped, fontSize: mid, width: size.width, height: size.height) {
                best = mid
                bestWrapped = candidateWrapped
                lo = mid
            } else {
                hi = mid
            }
            
            if hi - lo < 0.25 {
                break
            }
        }
        
        // Keep a small margin for UIKit/SwiftUI measurement differences,
        // but render larger so short and medium responses feel punchier.
        fittedFontSize = max(minFontSize, floor(best * 0.99))
        wrappedText = bestWrapped
        lineCount = max(1, bestWrapped.components(separatedBy: "\n").count)
    }
    
    private func textFits(_ wrappedText: String, fontSize: CGFloat, width: CGFloat, height: CGFloat) -> Bool {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = lineSpacing
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .paragraphStyle: paragraph
        ]
        
        let rect = NSAttributedString(string: wrappedText, attributes: attributes).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        return rect.width <= width + 0.5 && rect.height <= height + 0.5
    }
    
    /// Returns nil when a single word cannot fit at this font size.
    /// That tells the caller to reduce the font size rather than splitting words.
    private func wrapTextWithoutBreakingWords(_ text: String, fontSize: CGFloat, width: CGFloat) -> String? {
        let prepared = prepareTextForWrapping(text)
        let words = prepared.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        
        var lines: [String] = []
        var currentLine = ""
        
        for word in words {
            let proposal = currentLine.isEmpty ? word : "\(currentLine) \(word)"
            let proposalWidth = (proposal as NSString).size(withAttributes: attributes).width
            
            if proposalWidth <= width {
                currentLine = proposal
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                
                // If a single token doesn't fit, font is too large at this width.
                let wordWidth = (word as NSString).size(withAttributes: attributes).width
                if wordWidth <= width {
                    currentLine = word
                } else {
                    return nil
                }
            }
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        return lines.joined(separator: "\n")
    }
    
    /// Add legal break opportunities around punctuation clusters so we can wrap
    /// phrases like "HE…COULD…NOT…DO IT!" without splitting alphabetic words.
    private func prepareTextForWrapping(_ text: String) -> String {
        var result = text
        
        // Common punctuation that can safely create wrap points.
        // Preserve characters, only introduce spacing opportunities.
        let replacements: [(String, String)] = [
            ("…", "… "),
            ("—", " — "),
            ("/", "/ "),
            ("|", "| ")
        ]
        
        for (needle, replacement) in replacements {
            result = result.replacingOccurrences(of: needle, with: replacement)
        }
        
        // Collapse repeated spaces
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}


struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    @StateObject private var responseManager = ResponseManager()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var appState: AppState = .waiting
    @State private var currentResponse: Response?
    @State private var triangleOffset: CGSize = .zero
    @State private var bubbleOffset: CGSize = .zero
    @State private var loadingOpacity: Double = 0.0
    @State private var responseOpacity: Double = 0.0
    @State private var previousFaceDownState: Bool = false
    @State private var showSettings = false
    @State private var bubbles: [Bubble] = []
    @State private var preloadedResponse: Response?
    @State private var hasFlippedOnce = false
    @State private var initialHintOpacity: Double = 0.0
    @State private var hasPreloadedForCurrentFlip = false
    @State private var flipSequenceId: Int = 0 // Track flip cycles to cancel stale operations
    @State private var showIntroScreen = !ProcessInfo.processInfo.arguments.contains("-skipIntro")
    @State private var introBackgroundSetId = "classic"
    @State private var introThemeCycler: AnyCancellable?
    @State private var mainBackgroundOffset = CGSize(width: -8, height: -6)
    @State private var mainBackgroundScale: CGFloat = 1.0
    // Gentle parallax driven by device tilt so the wallpaper feels alive.
    @State private var mainParallax = CGSize.zero
    @State private var currentSphereSize: CGFloat = 0
    
    /// Sphere touches the sides of the screen; diameter = full width (with tiny margin).
    private let sphereEdgeInset: CGFloat = 0.98
    
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let haptics = HapticManager()
    private let sound = SoundManager()
    @AppStorage("soundEnabled") private var soundEnabled = true

    // Rare "shiny" fortunes ✨
    @State private var isShinyReveal = false
    @AppStorage("shinyFortuneCount") private var shinyCount = 0
    private let shinyChance = 0.015  // ~1 in 67

    // Phase 3 — dramatic reveal
    @State private var revealRise: CGFloat = 1     // 0 = deep in the murk, 1 = surfaced
    @State private var burstTrigger = 0            // bump to fire a reveal burst

    // Phase 4 — personality
    @State private var isSassyReveal = false       // the ball talked back
    @State private var glitchOverrideText: String? // non-nil while a reveal is "possessed"
    @State private var showDailyBanner = false     // "fortune of the day"
    @AppStorage("lastDailyFortuneDay") private var lastDailyFortuneDay = ""
    private let sassyChance = 0.05                 // ~1 in 20
    private let glitchChance = 0.06                // ~1 in 17

    // Phase 5 — growth
    @State private var translationText: String?    // same verdict, another era
    @State private var translationSetName: String?
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    // Phase 6 — decade dial + settle-it mode + skins
    @State private var showThemeDial = false
    @State private var showSettleIt = false
    @AppStorage("ballSkin") private var ballSkinRaw = "classic"
    @AppStorage("screenFXEnabled") private var screenFXEnabled = true

    // Phase 6.5 — fog mode (opt-in): blow to fog the glass, rub to wipe.
    @AppStorage("fogModeEnabled") private var fogModeEnabled = false
    @State private var blowDetector = BlowDetector()
    @State private var fogAmount: Double = 0
    @State private var fogWipes: [CGPoint] = []
    @State private var fogGeneration = 0

    init() {
        hapticGenerator.prepare()
    }
    
    private var selectedThemeName: String {
        if responseManager.selectedSetId == "random" {
            return "random"
        }
        return responseManager.availableSets
            .first(where: { $0.id == responseManager.effectiveSetId })?
            .name
            .lowercased() ?? "classic"
    }
    
    var body: some View {
        ZStack {
            ThemeWallpaperView(setId: showIntroScreen ? introBackgroundSetId : responseManager.effectiveSetId)
                .scaleEffect(showIntroScreen ? 1.0 : mainBackgroundScale)
                .offset(
                    x: showIntroScreen ? 0 : mainBackgroundOffset.width + mainParallax.width,
                    y: showIntroScreen ? 0 : mainBackgroundOffset.height + mainParallax.height
                )
                .animation(.easeInOut(duration: 0.6), value: introBackgroundSetId)
                .animation(.easeInOut(duration: 0.45), value: responseManager.effectiveSetId)
                .animation(.easeInOut(duration: 14.0), value: mainBackgroundOffset)
                .animation(.easeInOut(duration: 14.0), value: mainBackgroundScale)
                .ignoresSafeArea()
            
            // Keep the center readable while preserving chaotic wallpapers.
            RadialGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.42),
                    Color.black.opacity(0.66)
                ],
                center: .center,
                startRadius: 40,
                endRadius: 520
            )
            .ignoresSafeArea()
            
            // Magic 8 Ball sphere - centered using alignment instead of position
            GeometryReader { geometry in
                let size = sphereDiameter(for: geometry.size)
                let centerX = geometry.size.width / 2
                let centerY = geometry.size.height / 2
                // Ensure triangle fits within circle with padding
                let triangleSize = size * 0.5
                let constrainedOffset = constrainedTriangleOffset(
                    sphereSize: size,
                    triangleSize: triangleSize,
                    baseOffset: triangleOffset,
                    bubbleOffset: bubbleOffset
                )
                
                ZStack {
                    // Sphere base — drawn by the selected collectible skin.
                    (BallSkin(rawValue: ballSkinRaw) ?? .classic)
                        .sphere(size: size)
                        .frame(width: size, height: size)
                        .overlay(
                            // Subtle highlight for 3D effect
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.1),
                                            Color.clear
                                        ]),
                                        center: UnitPoint(x: 0.3, y: 0.3),
                                        startRadius: size * 0.1,
                                        endRadius: size * 0.4
                                    )
                                )
                                .frame(width: size, height: size)
                        )
                        .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 15)
                        .drawingGroup() // Optimize rendering
                        .overlay(
                            // Subtle edge text around the sphere (like "made in china • 30188")
                            ZStack {
                                // Top
                                Text("made in china • 30188 • weird little ideas")
                                    .font(.system(size: 7, weight: .ultraLight, design: .default))
                                    .foregroundColor(.black.opacity(0.12))
                                    .offset(y: -size * 0.48)
                                
                                // Bottom
                                Text("made in china • 30188 • weird little ideas")
                                    .font(.system(size: 7, weight: .ultraLight, design: .default))
                                    .foregroundColor(.black.opacity(0.12))
                                    .rotationEffect(.degrees(180))
                                    .offset(y: size * 0.48)
                                
                                // Left
                                Text("made in china • 30188 • weird little ideas")
                                    .font(.system(size: 7, weight: .ultraLight, design: .default))
                                    .foregroundColor(.black.opacity(0.12))
                                    .rotationEffect(.degrees(-90))
                                    .offset(x: -size * 0.48)
                                
                                // Right
                                Text("made in china • 30188 • weird little ideas")
                                    .font(.system(size: 7, weight: .ultraLight, design: .default))
                                    .foregroundColor(.black.opacity(0.12))
                                    .rotationEffect(.degrees(90))
                                    .offset(x: size * 0.48)
                            }
                        )
                    
                    // Triangle window (show when loading or showing response)
                    // Centered perfectly in the ZStack
                    if appState == .loading || (appState == .showingResponse && currentResponse != nil) {
                        TriangleWindow(
                            size: triangleSize,
                            offset: constrainedOffset,
                            isShiny: isShinyReveal && appState == .showingResponse
                        ) {
                            triangleContent(triangleSize: triangleSize)
                        }
                        .opacity(appState == .loading ? loadingOpacity : 1.0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // Bubbles overlay (when shaking) - optimized with drawingGroup
                    if !bubbles.isEmpty {
                        ForEach(bubbles) { bubble in
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.2),
                                            Color.clear
                                        ]),
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: bubble.size / 2
                                    )
                                )
                                .frame(width: bubble.size, height: bubble.size)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                                )
                                .position(
                                    x: size / 2 + bubble.x,
                                    y: size / 2 + bubble.y
                                )
                                .opacity(bubble.opacity)
                        }
                        .drawingGroup() // Optimize bubble rendering
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
                .position(x: centerX, y: centerY)
                .onAppear {
                    currentSphereSize = size
                }
                .onChange(of: geometry.size) { _, newSize in
                    currentSphereSize = sphereDiameter(for: newSize)
                }
            }
            
            // Initial hint at bottom (readable on any theme; over 8-ball area when no fortune)
            if !hasFlippedOnce && !showIntroScreen && currentResponse == nil && appState != .loading {
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        Text("think of a question and flip your phone over to reveal the answer")
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.72))
                            )
                            .padding(.horizontal, 32)
                            // Sits above the bottom-left "settle it" pill.
                            .padding(.bottom, geometry.safeAreaInsets.bottom + 68)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(initialHintOpacity)
                }
            }
            
            // Theme selector (safe-area aware so it stays below Dynamic Island).
            // Tapping the pill opens the decade dial; the gear opens full settings.
            GeometryReader { proxy in
                VStack(spacing: 10) {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                            showThemeDial.toggle()
                        }
                        hapticGenerator.impactOccurred(intensity: 0.4)
                    }) {
                        HStack(spacing: 8) {
                            Text(selectedThemeName)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Image(systemName: showThemeDial ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white.opacity(0.92))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.42))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.top, proxy.safeAreaInsets.top + 8)

                    if showThemeDial {
                        DecadeDial(
                            themes: responseManager.availableSets.map {
                                DialTheme(id: $0.id, emoji: $0.emoji, name: $0.name)
                            },
                            currentId: responseManager.effectiveSetId,
                            onSelect: { id in
                                responseManager.selectedSetId = id
                            }
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Settings gear (top-left, mirrors the sound toggle)
            if !showIntroScreen {
                GeometryReader { proxy in
                    VStack {
                        HStack {
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white.opacity(0.92))
                                    .frame(width: 38, height: 38)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.42))
                                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                    )
                            }
                            .padding(.leading, 16)
                            Spacer()
                        }
                        .padding(.top, proxy.safeAreaInsets.top + 8)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            // Per-era reveal burst (decorative particles)
            if !showIntroScreen {
                RevealBurst(
                    style: BurstStyle.forTheme(responseManager.effectiveSetId),
                    trigger: burstTrigger,
                    intense: isShinyReveal
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            // Era-flavored loading caption
            if appState == .loading && !showIntroScreen {
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        Text(loadingPhrase(for: responseManager.effectiveSetId))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.black.opacity(0.6)))
                            .padding(.bottom, geometry.safeAreaInsets.bottom + 28)
                            .opacity(loadingOpacity)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }

            // "Settle it" mode entry (bottom-left corner)
            if !showIntroScreen && appState != .showingResponse {
                GeometryReader { proxy in
                    VStack {
                        Spacer()
                        HStack {
                            Button(action: {
                                hapticGenerator.impactOccurred(intensity: 0.5)
                                showSettleIt = true
                            }) {
                                HStack(spacing: 6) {
                                    Text("⚖️")
                                        .font(.system(size: 14))
                                    Text("settle it")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.white.opacity(0.92))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.42))
                                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                )
                            }
                            .padding(.leading, 16)
                            Spacer()
                        }
                        .padding(.bottom, proxy.safeAreaInsets.bottom + 10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            // Sound on/off toggle (top-right, safe-area aware)
            if !showIntroScreen {
                GeometryReader { proxy in
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                soundEnabled.toggle()
                                hapticGenerator.impactOccurred(intensity: 0.4)
                            }) {
                                Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white.opacity(0.92))
                                    .frame(width: 38, height: 38)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.42))
                                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                    )
                            }
                            .padding(.trailing, 16)
                        }
                        .padding(.top, proxy.safeAreaInsets.top + 8)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            // "Fortune of the day" ceremony (first flip each day)
            if showDailyBanner && appState == .showingResponse && !showIntroScreen {
                GeometryReader { proxy in
                    VStack {
                        Text("✦ fortune of the day ✦")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.9, blue: 0.55))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.6))
                                    .overlay(
                                        Capsule().stroke(
                                            Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.7),
                                            lineWidth: 1.5
                                        )
                                    )
                            )
                            .padding(.top, proxy.safeAreaInsets.top + 56)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
                .zIndex(7)
            }

            // Post-reveal actions: translate across eras + share receipt
            if appState == .showingResponse && currentResponse != nil && !showIntroScreen {
                GeometryReader { proxy in
                    VStack(spacing: 10) {
                        Spacer()

                        // Cross-era translation result
                        if let translated = translationText, let setName = translationSetName {
                            VStack(spacing: 3) {
                                Text(setName.lowercased())
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.65))
                                Text("“\(translated.lowercased())”")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(Color.black.opacity(0.65))
                            )
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        HStack(spacing: 12) {
                            if !isSassyReveal {
                                Button(action: translateCurrentFortune) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.2.squarepath")
                                            .font(.system(size: 13, weight: .bold))
                                        Text("other eras")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                    }
                                    .foregroundColor(.white.opacity(0.92))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.42))
                                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                    )
                                }
                            }

                            Button(action: shareCurrentFortune) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("share")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.white.opacity(0.92))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.42))
                                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                )
                            }
                        }
                        .padding(.bottom, proxy.safeAreaInsets.bottom + 22)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .opacity(responseOpacity)
            }

            // Rare "shiny" fortune celebration
            if isShinyReveal && appState == .showingResponse && !showIntroScreen {
                ShinyBurst()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(5)
                VStack {
                    Spacer()
                    Text("✨ rare fortune  ·  #\(shinyCount) ✨")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 1.0, green: 0.9, blue: 0.55))
                        .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                        .padding(.bottom, 90)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
                .zIndex(6)
            }

            // Fog mode: breath condensation you rub away (under the scanlines).
            if fogModeEnabled && fogAmount > 0.01 && !showIntroScreen {
                FogOverlay(fogAmount: $fogAmount, wipes: $fogWipes)
                    .zIndex(8)
            }

            // Era-authentic screen treatment (CRT/VHS/LCD), above everything
            // visual but below the intro; purely decorative.
            if screenFXEnabled && !showIntroScreen {
                ScreenFXOverlay(fx: ScreenFX.forTheme(responseManager.effectiveSetId))
                    .zIndex(9)
            }

            if showIntroScreen {
                NostalgicIntroView(cyclingThemeSetId: introBackgroundSetId) {
                    stopIntroBackgroundCycler()
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) {
                        showIntroScreen = false
                    }
                    startInitialHintPulseIfNeeded()
                }
                .transition(.asymmetric(insertion: .opacity, removal: .scale(scale: 0.96).combined(with: .opacity)))
                .zIndex(10)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(responseManager: responseManager) {
                showIntroScreen = true
                showSettings = false
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ActivityShareSheet(items: [image])
                    .presentationDetents([.medium, .large])
            }
        }
        .fullScreenCover(isPresented: $showSettleIt) {
            SettleItView(
                themeSetId: responseManager.effectiveSetId,
                soundEnabled: soundEnabled,
                sound: sound,
                haptics: haptics
            ) {
                showSettleIt = false
            }
        }
        .onChange(of: motionManager.isFaceDown) { _, isFaceDown in
            let wasFaceDown = previousFaceDownState
            previousFaceDownState = isFaceDown
            handleOrientationChange(wasFaceDown: wasFaceDown, isFaceDown: isFaceDown)
        }
        .onReceive(motionManager.throttledShakeIntensity) { intensity in
            updateBubbleEffect(intensity: intensity)
        }
        .onReceive(Publishers.CombineLatest(motionManager.throttledTiltX, motionManager.throttledTiltY)) { tiltX, tiltY in
            updateGravityEffect()
            updateBackgroundParallax(tiltX: tiltX, tiltY: tiltY)
        }
        .onChange(of: responseManager.selectedSetId) {
            resetForThemeChange()
            retargetMainBackgroundDrift(animated: true)
        }
        .onChange(of: responseManager.effectiveSetId) {
            retargetMainBackgroundDrift(animated: true)
        }
        .onChange(of: showIntroScreen) { _, isShowingIntro in
            if isShowingIntro {
                startIntroBackgroundCyclerIfNeeded()
            } else {
                stopIntroBackgroundCycler()
                startMainBackgroundDriftIfNeeded()
            }
        }
        .onChange(of: fogModeEnabled) { _, enabled in
            if enabled { blowDetector.start() } else {
                blowDetector.stop()
                fogAmount = 0
                fogWipes = []
            }
        }
        .onAppear {
            blowDetector.onBlow = { handleBlow() }
            if fogModeEnabled { blowDetector.start() }
            introBackgroundSetId = randomThemeSetId()
            if !showIntroScreen {
                startInitialHintPulseIfNeeded()
                startMainBackgroundDriftIfNeeded()
            } else {
                startIntroBackgroundCyclerIfNeeded()
            }
        }
    }
    
    @ViewBuilder
    private func triangleContent(triangleSize: CGFloat) -> some View {
        if appState == .loading {
            // Loading animation with animated dots
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .opacity(loadingOpacity)
                }
            }
        } else if appState == .showingResponse, let response = currentResponse {
            TriangleFittedText(
                text: (glitchOverrideText ?? response.text).uppercased(),
                opacity: responseOpacity
            )
                // Surface from the depths: rise up, sharpen, settle.
                .offset(y: (1 - revealRise) * triangleSize * 0.32)
                .scaleEffect(0.72 + 0.28 * revealRise)
                .blur(radius: (1 - revealRise) * 3.5)
        } else {
            // Empty state - show nothing
            EmptyView()
        }
    }

    /// Era-flavored "summoning" line shown while the fortune loads.
    private func loadingPhrase(for themeId: String) -> String {
        switch themeId {
        case "aimy2k", "facebook2008", "myspace2005": return "connecting… 56k"
        case "matrix": return "decrypting…"
        case "tiktok2020", "twitterx2024": return "buffering…"
        case "deviantart2006": return "rendering…"
        case "shakespearean": return "consulting the muses…"
        case "harrypotter": return "casting…"
        case "boomers1958": return "dialing the operator…"
        case "genx": return "rewinding the tape…"
        case "nbajam", "sportscenter": return "reviewing the replay…"
        case "huntersthompson": return "chasing the vision…"
        case "genalpha", "genz": return "manifesting…"
        case "millennial", "tumblr2012", "xanga2002": return "loading vibes…"
        default: return "shaking…"
        }
    }

    /// "Possessed" reveal: show corrupted text that de-scrambles into the answer.
    private func runGlitchResolve(for text: String, sequenceId: Int) {
        let severities: [Double] = [0.9, 0.7, 0.45, 0.2]
        glitchOverrideText = Personality.scramble(text, severity: severities[0])
        for (i, severity) in severities.enumerated().dropFirst() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.13) {
                guard self.flipSequenceId == sequenceId else { return }
                self.glitchOverrideText = Personality.scramble(text, severity: severity)
                self.hapticGenerator.impactOccurred(intensity: 0.5)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(severities.count) * 0.13) {
            guard self.flipSequenceId == sequenceId else { return }
            self.glitchOverrideText = nil
        }
    }

    /// Blow detected → the glass fogs up; rubbing (FogOverlay) wipes it clear.
    /// The fog also slowly evaporates on its own.
    private func handleBlow() {
        guard fogModeEnabled, !showIntroScreen, appState != .faceDown else { return }
        fogGeneration += 1
        let generation = fogGeneration

        fogWipes = []
        hapticGenerator.impactOccurred(intensity: 0.6)
        withAnimation(.easeIn(duration: 0.9)) {
            fogAmount = 1.0
        }
        // Evaporate after a while unless a fresh blow re-fogged the glass.
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
            guard self.fogGeneration == generation else { return }
            withAnimation(.linear(duration: 5.0)) {
                self.fogAmount = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.2) {
                guard self.fogGeneration == generation else { return }
                self.fogWipes = []
            }
        }
    }

    /// Clear the per-reveal extras (glitch text, translation, banners).
    private func clearRevealExtras() {
        glitchOverrideText = nil
        translationText = nil
        translationSetName = nil
        isSassyReveal = false
        showDailyBanner = false
    }

    /// Same verdict, different era — each tap pulls a fresh translation.
    private func translateCurrentFortune() {
        guard let response = currentResponse else { return }
        guard let result = responseManager.translation(
            matching: response.type,
            excluding: responseManager.effectiveSetId
        ) else { return }
        hapticGenerator.impactOccurred(intensity: 0.5)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            translationText = result.text
            translationSetName = result.setName
        }
    }

    /// Render the era-styled receipt and open the share sheet.
    private func shareCurrentFortune() {
        guard let response = currentResponse else { return }
        let themeName = responseManager.availableSets
            .first(where: { $0.id == responseManager.effectiveSetId })?.name
            ?? responseManager.effectiveSetId
        shareImage = FortuneReceiptRenderer.image(
            themeName: themeName,
            answer: response.text,
            isShiny: isShinyReveal
        )
        if shareImage != nil {
            hapticGenerator.impactOccurred(intensity: 0.5)
            showShareSheet = true
        }
    }
    
    private func handleOrientationChange(wasFaceDown: Bool, isFaceDown: Bool) {
        if !wasFaceDown && isFaceDown {
            if !hasFlippedOnce {
                hasFlippedOnce = true
                withAnimation(.easeOut(duration: 0.35)) {
                    initialHintOpacity = 0.0
                }
            }
            
            // Just flipped face down - preload response ONCE and clear current
            // Increment sequence ID to invalidate any pending operations from previous flips
            flipSequenceId += 1
            let currentSequenceId = flipSequenceId
            
            appState = .faceDown
            isShinyReveal = false
            clearRevealExtras()
            showThemeDial = false
            hapticGenerator.prepare()
            hapticGenerator.impactOccurred()
            haptics.prepare()
            
            // Only preload if we haven't already for this flip cycle
            if !hasPreloadedForCurrentFlip {
                preloadedResponse = responseManager.getRandomResponse()
                if preloadedResponse == nil {
                    print("⚠️ Warning: Failed to preload response when flipping face down")
                }
                hasPreloadedForCurrentFlip = true
            }
            
            // Consolidate animations
            withAnimation(.easeInOut(duration: 0.3)) {
                triangleOffset = .zero
                bubbleOffset = .zero
                responseOpacity = 0.0
            }
            // Clear response after animation - only if this sequence is still current
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Only execute if this is still the current flip sequence
                guard self.flipSequenceId == currentSequenceId else { return }
                self.currentResponse = nil
                // Only set to waiting if we're still in faceDown state (didn't flip back up)
                if self.appState == .faceDown {
                    self.appState = .waiting
                }
            }
        } else if wasFaceDown && !isFaceDown {
            // Just flipped face up - show loading then response
            // Increment sequence ID to invalidate any pending operations from previous flips
            flipSequenceId += 1
            let currentSequenceId = flipSequenceId
            
            appState = .loading
            hapticGenerator.prepare()
            hapticGenerator.impactOccurred(intensity: 0.7)
            
            // Reset offsets
            triangleOffset = .zero
            bubbleOffset = .zero
            
            // Use preloaded response or get a new one if none was preloaded
            // Ensure we always have a response - if both are nil, something is wrong
            var response = preloadedResponse ?? responseManager.getRandomResponse()
            if response == nil {
                // Fallback: try to get response again (defensive)
                response = responseManager.getRandomResponse()
                print("⚠️ Warning: No preloaded response and getRandomResponse returned nil. Retrying...")
            }
            
            // Only proceed if we have a valid response
            guard let finalResponse = response else {
                print("❌ Error: Unable to get any response. Responses array may be empty.")
                appState = .waiting
                return
            }
            
            preloadedResponse = nil
            hasPreloadedForCurrentFlip = false // Reset flag for next flip cycle
            
            // Consolidate animations - fade in loading, then response
            loadingOpacity = 0.0
            responseOpacity = 0.0
            
            withAnimation(.easeIn(duration: 0.3)) {
                loadingOpacity = 1.0
            }
            
            // After brief loading animation, show response - only if this sequence is still current
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                // Only execute if this is still the current flip sequence and we're still loading
                guard self.flipSequenceId == currentSequenceId,
                      self.appState == .loading else {
                    return
                }
                // Roll for a rare shiny fortune ✨ (sassy replies only when not shiny)
                self.isShinyReveal = Double.random(in: 0...1) < self.shinyChance
                self.isSassyReveal = !self.isShinyReveal
                    && Double.random(in: 0...1) < self.sassyChance
                if self.isShinyReveal {
                    self.shinyCount += 1
                    self.haptics.playShiny()
                    if self.soundEnabled { self.sound.playShiny() }
                } else {
                    self.haptics.play(for: self.responseManager.effectiveSetId)
                    if self.soundEnabled { self.sound.play(for: self.responseManager.effectiveSetId) }
                }

                // The ball occasionally talks back instead of answering.
                var shownResponse = finalResponse
                if self.isSassyReveal {
                    shownResponse = Response(
                        text: Personality.sassyLine(for: self.responseManager.effectiveSetId),
                        type: .neutral
                    )
                }

                // First fortune of the calendar day gets a little ceremony.
                let today = ISO8601DateFormatter.dayStamp()
                if self.lastDailyFortuneDay != today {
                    self.lastDailyFortuneDay = today
                    self.showDailyBanner = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation(.easeOut(duration: 0.6)) { self.showDailyBanner = false }
                    }
                }

                self.currentResponse = shownResponse
                self.appState = .showingResponse

                // Occasionally the reveal is "possessed": the text surfaces
                // corrupted, then resolves to the real answer.
                if !self.isShinyReveal && Double.random(in: 0...1) < self.glitchChance {
                    self.runGlitchResolve(for: shownResponse.text, sequenceId: currentSequenceId)
                }

                // Liquid "float-up": the answer starts deep in the murk and
                // buoyantly rises/sharpens into view.
                self.revealRise = 0.0
                withAnimation(.spring(response: 0.7, dampingFraction: 0.62)) {
                    self.revealRise = 1.0
                }
                // Fire the theme's reveal burst.
                self.burstTrigger += 1

                // Fade out loading, fade in response in one animation
                withAnimation(.easeIn(duration: 0.5)) {
                    self.loadingOpacity = 0.0
                    self.responseOpacity = 1.0
                }
            }
        }
    }
    
    private func startInitialHintPulseIfNeeded() {
        guard !hasFlippedOnce else { return }
        
        initialHintOpacity = 0.18
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            initialHintOpacity = 0.82
        }
    }
    
    private func startIntroBackgroundCyclerIfNeeded() {
        guard showIntroScreen else { return }
        guard introThemeCycler == nil else { return }
        
        introThemeCycler = Timer.publish(every: 1.8, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let nextTheme = randomThemeSetId(excluding: introBackgroundSetId)
                withAnimation(.easeInOut(duration: 0.55)) {
                    introBackgroundSetId = nextTheme
                }
            }
    }
    
    private func stopIntroBackgroundCycler() {
        introThemeCycler?.cancel()
        introThemeCycler = nil
    }
    
    private func startMainBackgroundDriftIfNeeded() {
        guard !showIntroScreen else { return }
        
        if reduceMotion {
            mainBackgroundOffset = .zero
            mainBackgroundScale = 1.0
            return
        }
        
        // Base overscan gives the float + parallax room to move without exposing edges.
        mainBackgroundScale = 1.07
        retargetMainBackgroundDrift(animated: false)

        // Slow "breathing" zoom on its own cadence...
        withAnimation(.easeInOut(duration: 11.0).repeatForever(autoreverses: true)) {
            mainBackgroundScale = 1.11
        }
        // ...and a gentle wandering drift on a different cadence so it feels organic.
        withAnimation(.easeInOut(duration: 16.0).repeatForever(autoreverses: true)) {
            mainBackgroundOffset = CGSize(
                width: CGFloat.random(in: -18...18),
                height: CGFloat.random(in: -12...12)
            )
        }
    }
    
    private func retargetMainBackgroundDrift(animated: Bool) {
        guard !showIntroScreen else { return }
        guard !reduceMotion else {
            mainBackgroundOffset = .zero
            mainBackgroundScale = 1.0
            return
        }
        
        let nextOffset = CGSize(
            width: CGFloat.random(in: -14...14),
            height: CGFloat.random(in: -10...10)
        )
        
        if animated {
            withAnimation(.easeInOut(duration: 1.1)) {
                mainBackgroundOffset = nextOffset
            }
        } else {
            mainBackgroundOffset = nextOffset
        }
    }

    /// Subtle tilt parallax so the wallpaper drifts as the phone is held/turned.
    /// Kept small and inside the base overscan so no edges are ever exposed.
    private func updateBackgroundParallax(tiltX: Double, tiltY: Double) {
        guard !showIntroScreen, !reduceMotion else {
            if mainParallax != .zero {
                withAnimation(.easeOut(duration: 0.4)) { mainParallax = .zero }
            }
            return
        }

        let maxX: CGFloat = 20
        let maxY: CGFloat = 10
        let target = CGSize(
            width: max(-maxX, min(maxX, CGFloat(tiltX) * 26)),
            height: max(-maxY, min(maxY, CGFloat(tiltY) * 14))
        )
        withAnimation(.easeOut(duration: 0.35)) {
            mainParallax = target
        }
    }
    
    private func randomThemeSetId(excluding current: String? = nil) -> String {
        let ids = responseManager.availableSets.map(\.id)
        guard !ids.isEmpty else { return "classic" }
        
        if let current {
            let filtered = ids.filter { $0 != current }
            return filtered.randomElement() ?? ids.randomElement() ?? "classic"
        }
        
        return ids.randomElement() ?? "classic"
    }
    
    private func resetForThemeChange() {
        // Invalidate pending delayed operations tied to previous theme/flip cycle.
        flipSequenceId += 1
        appState = .waiting
        currentResponse = nil
        preloadedResponse = nil
        hasPreloadedForCurrentFlip = false
        clearRevealExtras()
        
        loadingOpacity = 0.0
        responseOpacity = 0.0
        triangleOffset = .zero
        bubbleOffset = .zero
        bubbles.removeAll()
        
        // If user has not flipped yet, keep the hint behavior intact after theme switch.
        if !hasFlippedOnce && !showIntroScreen {
            startInitialHintPulseIfNeeded()
        }
    }
    
    
    private func updateBubbleEffect(intensity: Double) {
        // Only apply bubble effect when face down or loading
        guard appState == .faceDown || appState == .loading else {
            // Don't clear bubbles immediately - let them fade naturally
            return
        }
        
        if intensity > 0.1 {
            // Create random bubble movement based on shake intensity
            let maxOffset: CGFloat = 15.0 * CGFloat(intensity)
            let randomX = CGFloat.random(in: -maxOffset...maxOffset)
            let randomY = CGFloat.random(in: -maxOffset...maxOffset)
            
            withAnimation(.easeOut(duration: 0.1)) {
                bubbleOffset = CGSize(width: randomX, height: randomY)
            }
            
            // Add more bubbles when shaking - max 7 bubbles total
            let maxBubbleCount = min(7, Int(intensity * 7) + 1) // Max 7 bubbles, at least 1 when shaking
            
            if bubbles.count < maxBubbleCount {
                let newBubbles = (bubbles.count..<maxBubbleCount).map { _ in
                    createRandomBubble(intensity: intensity)
                }
                bubbles.append(contentsOf: newBubbles)
            }
            
            // Batch update bubbles for better performance
            let updates = bubbles.indices.map { i -> (Int, CGFloat, CGFloat) in
                (i, CGFloat.random(in: -3...3), CGFloat.random(in: -2...2))
            }
            withAnimation(.easeInOut(duration: 0.5)) {
                for (i, dx, dy) in updates {
                    bubbles[i].x += dx
                    bubbles[i].y += dy
                }
            }
        } else {
            // Gradually return to center when not shaking
            withAnimation(.easeOut(duration: 0.3)) {
                bubbleOffset = .zero
            }
            
            // Fade out bubbles individually at different rates over 12 seconds
            for i in bubbles.indices {
                let fadeDuration = Double.random(in: 8.0...12.0) // Random fade duration between 8-12 seconds
                
                withAnimation(.easeOut(duration: fadeDuration)) {
                    bubbles[i].opacity = 0.0
                }
            }
            
            // Remove fully faded bubbles after 12 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 12.0) {
                bubbles.removeAll { $0.opacity <= 0.0 }
            }
        }
    }
    
    private func createRandomBubble(intensity: Double) -> Bubble {
        let sphereSize = effectiveSphereSize
        let maxRadius = sphereSize * 0.35 // Bubbles can appear around the sphere
        
        return Bubble(
            id: UUID(),
            x: CGFloat.random(in: -maxRadius...maxRadius),
            y: CGFloat.random(in: -maxRadius...maxRadius),
            size: CGFloat.random(in: 3...12), // More size variety
            opacity: Double.random(in: 0.4...0.9) // More opacity variety
        )
    }
    
    private func updateGravityEffect() {
        // Only apply gravity effect when showing response or loading
        guard appState == .showingResponse || appState == .loading else {
            triangleOffset = .zero
            return
        }
        
        // Convert tilt to offset (tiltX and tiltY range from -1 to 1)
        // When device tilts right, tiltX is positive, so triangle drifts right
        // When device tilts down, tiltY is positive, so triangle drifts down
        // Make it more responsive with larger max drift
        let sphereSize = effectiveSphereSize
        let maxDrift: CGFloat = sphereSize * 0.15 // More responsive - 15% of sphere size
        let driftX = CGFloat(motionManager.tiltX) * maxDrift
        let driftY = CGFloat(motionManager.tiltY) * maxDrift
        
        // Constrain to stay within circle bounds.
        // Use asymmetric vertical bounds: the triangle can travel farther down than up
        // because the bottom tip is closer to center than top corners.
        let triangleSize = sphereSize * 0.5
        let bounds = triangleMovementBounds(
            sphereSize: sphereSize,
            triangleSize: triangleSize,
            padding: 0
        )
        
        let constrainedX = max(-bounds.horizontal, min(bounds.horizontal, driftX))
        let constrainedY = max(-bounds.upward, min(bounds.downward, driftY))
        
        withAnimation(.easeOut(duration: 0.15)) {
            triangleOffset = CGSize(width: constrainedX, height: constrainedY)
        }
    }
    
    private func constrainedTriangleOffset(
        sphereSize: CGFloat,
        triangleSize: CGFloat,
        baseOffset: CGSize,
        bubbleOffset: CGSize
    ) -> CGSize {
        let combined = CGSize(width: baseOffset.width + bubbleOffset.width, height: baseOffset.height + bubbleOffset.height)
        let bounds = triangleMovementBounds(
            sphereSize: sphereSize,
            triangleSize: triangleSize,
            padding: 4
        )
        
        return CGSize(
            width: max(-bounds.horizontal, min(bounds.horizontal, combined.width)),
            height: max(-bounds.upward, min(bounds.downward, combined.height))
        )
    }
    
    private func triangleMovementBounds(
        sphereSize: CGFloat,
        triangleSize: CGFloat,
        padding: CGFloat
    ) -> (horizontal: CGFloat, upward: CGFloat, downward: CGFloat) {
        let circleRadius = sphereSize / 2
        let topCornerDistance = triangleSize * sqrt(2) / 2
        let bottomTipDistance = triangleSize / 2
        
        let horizontal = max(0, circleRadius - topCornerDistance - padding)
        let upward = max(0, circleRadius - topCornerDistance - padding)
        let downward = max(0, circleRadius - bottomTipDistance - padding)
        
        return (horizontal, upward, downward)
    }
    
    private func sphereDiameter(for containerSize: CGSize) -> CGFloat {
        // Sphere touches left/right edges; use full width (with optional inset).
        let width = containerSize.width * sphereEdgeInset
        let maxByHeight = containerSize.height
        return min(width, maxByHeight)
    }
    
    private var effectiveSphereSize: CGFloat {
        if currentSphereSize > 0 {
            return currentSphereSize
        }
        let screen = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds.size ?? CGSize(width: 393, height: 852)
        return sphereDiameter(for: screen)
    }
}

struct NostalgicIntroView: View {
    let cyclingThemeSetId: String
    let onGetStarted: () -> Void
    @State private var isFloating = false
    @State private var isPulsingCTA = false
    @State private var isTilted = false
    @State private var backgroundOffset = CGSize(width: -18, height: -12)
    @State private var backgroundScale: CGFloat = 1.0
    @State private var backgroundRotation: Double = -1.2
    
    var body: some View {
        ZStack {
            ThemeWallpaperView(setId: cyclingThemeSetId)
                .scaleEffect(backgroundScale * ThemeBackgroundLayout.motionOverscan)
                .rotationEffect(.degrees(backgroundRotation))
                .offset(backgroundOffset)
                .ignoresSafeArea()
            
            LinearGradient(
                colors: [
                    Color.black.opacity(0.22),
                    Color.black.opacity(0.38),
                    Color.black.opacity(0.52)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Memphis-style geometric accents to push the throwback arcade vibe.
            Circle()
                .fill(Color.yellow.opacity(0.33))
                .frame(width: 190, height: 190)
                .blur(radius: 1)
                .offset(x: -130, y: -260)
            
            Circle()
                .fill(Color.cyan.opacity(0.32))
                .frame(width: 130, height: 130)
                .offset(x: 150, y: -170)
            
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .frame(width: 150, height: 44)
                .rotationEffect(.degrees(-15))
                .offset(x: -125, y: 180)
            
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.17))
                .frame(width: 180, height: 52)
                .rotationEffect(.degrees(17))
                .offset(x: 145, y: 250)
            
            VStack(spacing: 20) {
                Text("try me!")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.98, green: 0.57, blue: 0.1))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.7), lineWidth: 2)
                            )
                    )
                    .rotationEffect(.degrees(isTilted ? -11 : -7))
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 3)
                
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 0.16, green: 0.17, blue: 0.26),
                                        Color.black
                                    ],
                                    center: .topLeading,
                                    startRadius: 10,
                                    endRadius: 95
                                )
                            )
                            .frame(width: 150, height: 150)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.28), lineWidth: 2)
                            )
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 72, height: 72)
                        
                        Text("8")
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                    }
                    .offset(y: isFloating ? -8 : 6)
                    .scaleEffect(isFloating ? 1.02 : 0.98)
                    
                    Text("magic eight")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 3)
                        .multilineTextAlignment(.center)
                    
                    Text("ask a question. flip over for an answer.")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.98, green: 0.94, blue: 0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                
                Button(action: onGetStarted) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .black))
                        Text("get started")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 20, weight: .black))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.93, green: 0.2, blue: 0.44),
                                        Color(red: 1.0, green: 0.5, blue: 0.16)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.65), lineWidth: 2)
                            )
                    )
                    .shadow(color: .black.opacity(0.28), radius: 7, x: 0, y: 5)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .scaleEffect(isPulsingCTA ? 1.02 : 0.98)
                
                Text("a totally rad throwback to 1995")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 36)
        }
        .onChange(of: cyclingThemeSetId) {
            retargetBackdropMotion(animated: true)
        }
        .onAppear {
            retargetBackdropMotion(animated: false)
            
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                backgroundScale = 1.03
            }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                isFloating = true
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                isPulsingCTA = true
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isTilted = true
            }
        }
    }
    
    private func retargetBackdropMotion(animated: Bool) {
        let nextOffset = CGSize(
            width: CGFloat.random(in: -28...28),
            height: CGFloat.random(in: -22...22)
        )
        let nextRotation = Double.random(in: -1.8...1.8)
        
        if animated {
            withAnimation(.easeInOut(duration: 1.2)) {
                backgroundOffset = nextOffset
                backgroundRotation = nextRotation
            }
        } else {
            backgroundOffset = nextOffset
            backgroundRotation = nextRotation
        }
    }
}

struct ThemeWallpaperView: View {
    let setId: String
    
    var body: some View {
        ThemeReferenceBackdrop(setId: setId)
        .allowsHitTesting(false)
    }
}

private enum ThemeBackgroundLayout {
    /// Extra headroom so intro drift/rotation never exposes empty edges.
    static let motionOverscan: CGFloat = 1.08
}

private struct StickerWord: View {
    let text: String
    let tint: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .black, design: .rounded))
            .foregroundColor(.white.opacity(0.88))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tint.opacity(0.4))
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.35), lineWidth: 1.5)
                    )
            )
            .shadow(color: .black.opacity(0.22), radius: 3, x: 0, y: 2)
    }
}

private struct ThemeReferenceBackdrop: View {
    let setId: String
    
    var body: some View {
        GeometryReader { geo in
            if let assetName = referenceAssetName {
                // The theme art is full-bleed portrait, so a plain aspect-fill
                // covers the whole screen (top, bottom, sides) on every iPhone,
                // cropping only the small amount needed for the device aspect.
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .saturation(0.98)
                    .contrast(1.03)
            } else {
                Color.black
            }
        }
        .ignoresSafeArea()
    }
    
    private var referenceAssetName: String? {
        switch setId {
        case "classic":
            return "theme-bg-classic"
        case "shakespearean":
            return "theme-bg-shakespearean"
        case "huntersthompson":
            return "theme-bg-huntersthompson"
        case "genalpha":
            return "theme-bg-genalpha"
        case "genz":
            return "theme-bg-genz"
        case "millennial":
            return "theme-bg-millennial"
        case "genx":
            return "theme-bg-genx"
        case "boomers1958":
            return "theme-bg-boomers1958"
        case "twitterx2024":
            return "theme-bg-twitterx2024"
        case "tiktok2020":
            return "theme-bg-tiktok2020"
        case "tumblr2012":
            return "theme-bg-tumblr2012"
        case "facebook2008":
            return "theme-bg-facebook2008"
        case "deviantart2006":
            return "theme-bg-deviantart2006"
        case "myspace2005":
            return "theme-bg-myspace2005"
        case "xanga2002":
            return "theme-bg-xanga2002"
        case "aimy2k":
            return "theme-bg-aimy2k"
        case "harrypotter":
            return "theme-bg-harrypotter"
        case "matrix":
            return "theme-bg-matrix"
        case "nbajam":
            return "theme-bg-nbajam"
        case "sportscenter":
            return "theme-bg-sportscenter"
        default:
            return nil
        }
    }
}

private struct WallpaperRecipe {
    let baseGradient: LinearGradient
    let accentA: Color
    let accentB: Color
    let stickerWords: [String]
    let specialOverlay: AnyView
    
    static let classicEightBall = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color(red: 0.06, green: 0.08, blue: 0.24), Color(red: 0.15, green: 0.05, blue: 0.33), .black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentA: Color(red: 0.13, green: 0.54, blue: 0.98),
        accentB: Color(red: 0.62, green: 0.21, blue: 0.89),
        stickerWords: ["TRY ME", "ASK AGAIN", "MYSTIC", "8 BALL"],
        specialOverlay: AnyView(EmptyView())
    )
    
    static let sportsCenter = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color(red: 0.27, green: 0.16, blue: 0.28), Color(red: 0.35, green: 0.24, blue: 0.31), Color(red: 0.14, green: 0.08, blue: 0.11)],
            startPoint: .topLeading,
            endPoint: .bottom
        ),
        accentA: Color(red: 0.98, green: 0.22, blue: 0.13),
        accentB: Color(red: 0.94, green: 0.77, blue: 0.42),
        stickerWords: ["SPORTSCENTER", "ESPN", "TOP PLAY", "LIVE"],
        specialOverlay: AnyView(
            ZStack {
                VStack(spacing: 0) {
                    // Faux studio wall + stage lights
                    LinearGradient(
                        colors: [Color(red: 0.46, green: 0.27, blue: 0.4), Color(red: 0.29, green: 0.21, blue: 0.34)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 130)
                    .overlay(
                        HStack(spacing: 3) {
                            ForEach(0..<8, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 85)
                            }
                        }
                        .padding(.horizontal, 25)
                    )
                    Spacer()
                }
                
                // Center screen block with repeating title pattern
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.57, green: 0.45, blue: 0.29), Color(red: 0.36, green: 0.28, blue: 0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 220, height: 130)
                    .overlay(
                        VStack(spacing: 6) {
                            ForEach(0..<4, id: \.self) { _ in
                                Text("SPORTSCENTER")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 0.89, green: 0.82, blue: 0.62).opacity(0.75))
                            }
                            Text("ESPN")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                    }
                    )
                    .offset(y: -35)
                
                // Classic lower-third bars
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(Color.black.opacity(0.65))
                        .frame(height: 28)
                        .overlay(
                            HStack {
                                Text("RECEDAVIS")
                                Spacer()
                                Text("GARYMILLER")
                            }
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 16)
                        )
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.62, green: 0.08, blue: 0.08), Color(red: 0.85, green: 0.35, blue: 0.1), Color(red: 0.26, green: 0.05, blue: 0.05)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 22)
                        .overlay(
                            HStack {
                                Text("ESPN")
                                Spacer()
                                Text("SPORTSCENTER")
                            }
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.88))
                            .padding(.horizontal, 18)
                        )
                }
                
                // CRT wash
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .blendMode(.screen)
            }
        )
    )
    
    static let facebook2008 = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color(red: 0.83, green: 0.87, blue: 0.95), Color(red: 0.75, green: 0.81, blue: 0.9), Color(red: 0.63, green: 0.72, blue: 0.86)],
            startPoint: .top,
            endPoint: .bottom
        ),
        accentA: Color(red: 0.24, green: 0.38, blue: 0.68),
        accentB: Color(red: 0.29, green: 0.45, blue: 0.74),
        stickerWords: ["thefacebook", "poke", "profile", "status"],
        specialOverlay: AnyView(
            ZStack {
                VStack(spacing: 0) {
                    // Period-correct top nav
                    Rectangle()
                        .fill(Color(red: 0.23, green: 0.36, blue: 0.65))
                        .frame(height: 42)
                        .overlay(
                            HStack {
                                Text("[ thefacebook ]")
                                    .font(.system(size: 19, weight: .black, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                                Spacer()
                                Text("home  search  global  social net")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.72))
                            }
                            .padding(.horizontal, 12)
                        )
                    Spacer()
                }
                
                HStack(alignment: .top, spacing: 8) {
                    // Left column
                    VStack(alignment: .leading, spacing: 7) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.white.opacity(0.95))
                            .frame(height: 24)
                            .overlay(
                                HStack {
                                    Text("quick search")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Rectangle()
                                        .fill(Color(red: 0.26, green: 0.48, blue: 0.8))
                                        .frame(width: 22, height: 16)
                                }
                                .padding(.horizontal, 6)
                            )
                        ForEach(0..<6, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.white.opacity(0.85))
                                .frame(height: 11)
                        }
                    }
                    .frame(width: 108)
                    .padding(8)
                    .background(Color.white.opacity(0.55))
                    .overlay(Rectangle().stroke(Color(red: 0.34, green: 0.48, blue: 0.71).opacity(0.5), lineWidth: 1))
                    
                    // Main profile/content blocks
                    VStack(spacing: 8) {
                        Rectangle()
                            .fill(Color(red: 0.24, green: 0.38, blue: 0.67))
                            .frame(height: 22)
                            .overlay(
                                HStack {
                                    Text("Brian Moore's Profile")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.9))
                                    Spacer()
                                }
                                .padding(.horizontal, 7)
                            )
                        
                        HStack(spacing: 8) {
                            VStack(spacing: 7) {
                                panel(title: "Picture", height: 95)
                                panel(title: "Connection", height: 52)
                                panel(title: "Mutual Friends", height: 52)
                            }
                            VStack(spacing: 7) {
                                panel(title: "Information", height: 140)
                                panel(title: "Personal Info", height: 67)
                            }
                        }
                    }
                }
                .padding(.top, 56)
                .padding(.horizontal, 10)
            }
        )
    )
    
    private static func panel(title: String, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(red: 0.24, green: 0.38, blue: 0.67))
                .frame(height: 16)
                .overlay(
                    HStack {
                        Text(title)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                        Spacer()
                    }
                    .padding(.horizontal, 5)
                )
            Rectangle()
                .fill(Color.white.opacity(0.93))
                .frame(height: max(10, height - 16))
                .overlay(
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(0..<4, id: \.self) { _ in
                            Rectangle()
                                .fill(Color(red: 0.23, green: 0.36, blue: 0.65).opacity(0.22))
                                .frame(height: 5)
                        }
                    }
                    .padding(5)
                )
        }
        .overlay(Rectangle().stroke(Color(red: 0.34, green: 0.48, blue: 0.71).opacity(0.65), lineWidth: 1))
        .frame(height: height)
    }
    
    static let mySpace2005 = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color(red: 0.05, green: 0.02, blue: 0.08), Color(red: 0.22, green: 0.05, blue: 0.3), Color(red: 0.05, green: 0.0, blue: 0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentA: Color(red: 0.95, green: 0.24, blue: 0.62),
        accentB: Color(red: 0.66, green: 0.26, blue: 0.98),
        stickerWords: ["TOP 8", "rawr", "glitter", "layout css"],
        specialOverlay: AnyView(
            ZStack {
                ForEach(0..<45, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(index % 3 == 0 ? 0.45 : 0.2))
                        .frame(width: 3 + CGFloat(index % 4), height: 3 + CGFloat(index % 4))
                        .offset(x: CGFloat((index % 10) * 35 - 170), y: CGFloat((index / 10) * 70 - 260))
                }
            }
        )
    )
    
    static let aim2001 = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color(red: 0.02, green: 0.03, blue: 0.12), Color(red: 0.02, green: 0.12, blue: 0.36), Color(red: 0.02, green: 0.22, blue: 0.48)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentA: Color(red: 1.0, green: 0.94, blue: 0.35),
        accentB: Color(red: 0.31, green: 0.84, blue: 1.0),
        stickerWords: ["brb", "afk", "away msg", "buddy list"],
        specialOverlay: AnyView(
            VStack {
                HStack(spacing: 5) {
                    ForEach(0..<9, id: \.self) { _ in
                        Circle().fill(Color.green.opacity(0.42)).frame(width: 10, height: 10)
                    }
                }
                Spacer()
            }
            .padding(.top, 50)
        )
    )
    
    static let xanga2002 = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color(red: 0.99, green: 0.86, blue: 0.93), Color(red: 0.86, green: 0.79, blue: 1.0), Color(red: 0.72, green: 0.86, blue: 1.0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentA: Color(red: 0.95, green: 0.35, blue: 0.58),
        accentB: Color(red: 0.63, green: 0.4, blue: 0.96),
        stickerWords: ["xoxo", "dear diary", "mood", "song of day"],
        specialOverlay: AnyView(
            VStack(spacing: 9) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.42))
                        .frame(height: 16)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 76)
        )
    )
    
    static let deviantArt2006 = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color(red: 0.07, green: 0.14, blue: 0.1), Color(red: 0.11, green: 0.24, blue: 0.18), Color(red: 0.04, green: 0.08, blue: 0.07)],
            startPoint: .top,
            endPoint: .bottom
        ),
        accentA: Color(red: 0.54, green: 0.88, blue: 0.58),
        accentB: Color(red: 0.32, green: 0.7, blue: 0.58),
        stickerWords: ["fave + watch", "oc", "art jam", "journal"],
        specialOverlay: AnyView(
            ZStack {
                ForEach(0..<7, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                        .frame(width: 220 - CGFloat(i * 18), height: 130 - CGFloat(i * 12))
                        .rotationEffect(.degrees(Double(i * 7) - 16))
                }
            }
        )
    )
    
    static let twitter2025 = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color.black, Color(red: 0.07, green: 0.11, blue: 0.15), Color(red: 0.08, green: 0.19, blue: 0.28)],
            startPoint: .top,
            endPoint: .bottom
        ),
        accentA: Color(red: 0.18, green: 0.8, blue: 1.0),
        accentB: Color(red: 0.43, green: 0.62, blue: 1.0),
        stickerWords: ["ratio", "timeline", "community notes", "bookmark"],
        specialOverlay: AnyView(EmptyView())
    )
    
    static let tiktok2020 = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color.black, Color(red: 0.1, green: 0.08, blue: 0.16), Color(red: 0.14, green: 0.02, blue: 0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentA: Color(red: 0.09, green: 0.95, blue: 0.95),
        accentB: Color(red: 1.0, green: 0.22, blue: 0.56),
        stickerWords: ["for you", "slay", "vibes", "trend"],
        specialOverlay: AnyView(
            ZStack {
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 14).frame(width: 220, height: 220)
                Circle().stroke(Color(red: 0.09, green: 0.95, blue: 0.95).opacity(0.45), lineWidth: 10).frame(width: 190, height: 190).offset(x: -8, y: -7)
                Circle().stroke(Color(red: 1.0, green: 0.22, blue: 0.56).opacity(0.45), lineWidth: 10).frame(width: 190, height: 190).offset(x: 8, y: 7)
            }
        )
    )
    
    static let tumblr2012 = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color(red: 0.05, green: 0.07, blue: 0.15), Color(red: 0.14, green: 0.09, blue: 0.25), Color(red: 0.09, green: 0.07, blue: 0.2)],
            startPoint: .top,
            endPoint: .bottom
        ),
        accentA: Color(red: 0.67, green: 0.66, blue: 0.86),
        accentB: Color(red: 0.84, green: 0.57, blue: 0.92),
        stickerWords: ["reblog", "aesthetic", "otp", "feels"],
        specialOverlay: AnyView(
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 170, height: 170)
                    .offset(x: 120, y: -230)
                ForEach(0..<16, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: CGFloat((i % 3) + 2))
                        .offset(x: CGFloat((i * 21) - 160), y: CGFloat((i % 5) * 70 - 280))
                }
            }
        )
    )
    
    static let matrixCode = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color.black, Color(red: 0.0, green: 0.12, blue: 0.03), Color.black],
            startPoint: .top,
            endPoint: .bottom
        ),
        accentA: Color(red: 0.0, green: 0.8, blue: 0.22),
        accentB: Color(red: 0.2, green: 0.95, blue: 0.45),
        stickerWords: ["the one", "oracle", "glitch", "red pill"],
        specialOverlay: AnyView(
            HStack(alignment: .top, spacing: 10) {
                ForEach(0..<14, id: \.self) { column in
                    VStack(spacing: 6) {
                        ForEach(0..<22, id: \.self) { row in
                            Text((row + column).isMultiple(of: 3) ? "1" : "0")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.green.opacity(row.isMultiple(of: 2) ? 0.5 : 0.22))
                        }
                    }
                }
            }
            .padding(.top, 10)
        )
    )
    
    static let arcadeSports = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color(red: 0.25, green: 0.05, blue: 0.0), Color(red: 0.58, green: 0.1, blue: 0.02), Color(red: 0.89, green: 0.35, blue: 0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentA: Color(red: 1.0, green: 0.84, blue: 0.16),
        accentB: Color(red: 0.98, green: 0.25, blue: 0.08),
        stickerWords: ["ON FIRE", "BOOMSHAKALAKA", "DOWNTOWN", "GAME TIME"],
        specialOverlay: AnyView(
            VStack {
                HStack(spacing: 0) {
                    ForEach(0..<12, id: \.self) { i in
                        Rectangle()
                            .fill(i.isMultiple(of: 2) ? Color.black.opacity(0.2) : Color.white.opacity(0.12))
                            .frame(height: 16)
                    }
                }
                Spacer()
            }
            .padding(.top, 55)
        )
    )
    
    static let wizardNight = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color(red: 0.03, green: 0.05, blue: 0.2), Color(red: 0.11, green: 0.08, blue: 0.25), Color(red: 0.18, green: 0.1, blue: 0.32)],
            startPoint: .top,
            endPoint: .bottom
        ),
        accentA: Color(red: 0.95, green: 0.78, blue: 0.35),
        accentB: Color(red: 0.68, green: 0.59, blue: 0.97),
        stickerWords: ["owl post", "house points", "spell", "quidditch"],
        specialOverlay: AnyView(
            ZStack {
                ForEach(0..<24, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: CGFloat((i % 3) + 2), height: CGFloat((i % 3) + 2))
                        .offset(x: CGFloat((i * 27) - 210), y: CGFloat((i % 7) * 60 - 300))
                }
            }
        )
    )
    
    static let genZNeon = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color(red: 0.13, green: 0.04, blue: 0.25), Color(red: 0.03, green: 0.18, blue: 0.33), Color(red: 0.03, green: 0.06, blue: 0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentA: Color(red: 0.0, green: 0.95, blue: 0.9),
        accentB: Color(red: 0.99, green: 0.36, blue: 0.8),
        stickerWords: ["no cap", "W", "it gives", "valid"],
        specialOverlay: AnyView(EmptyView())
    )
    
    static let genAlphaCandy = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color(red: 0.96, green: 0.5, blue: 0.76), Color(red: 0.54, green: 0.73, blue: 1.0), Color(red: 0.98, green: 0.86, blue: 0.45)],
            startPoint: .top,
            endPoint: .bottom
        ),
        accentA: Color(red: 1.0, green: 0.22, blue: 0.56),
        accentB: Color(red: 0.23, green: 0.77, blue: 1.0),
        stickerWords: ["OMG", "LOL", "HIGH FIVE", "BRO"],
        specialOverlay: AnyView(EmptyView())
    )
    
    static let millennialTeal = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color(red: 0.22, green: 0.44, blue: 0.58), Color(red: 0.18, green: 0.52, blue: 0.54), Color(red: 0.13, green: 0.27, blue: 0.34)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentA: Color(red: 1.0, green: 0.62, blue: 0.32),
        accentB: Color(red: 0.94, green: 0.37, blue: 0.4),
        stickerWords: ["vibes", "low key", "classic", "snack break"],
        specialOverlay: AnyView(EmptyView())
    )
    
    static let genXMixtape = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color(red: 0.06, green: 0.11, blue: 0.26), Color(red: 0.32, green: 0.14, blue: 0.44), Color(red: 0.14, green: 0.06, blue: 0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accentA: Color(red: 0.95, green: 0.74, blue: 0.21),
        accentB: Color(red: 0.33, green: 0.88, blue: 0.98),
        stickerWords: ["rad", "mixtape", "totally", "dude"],
        specialOverlay: AnyView(EmptyView())
    )
    
    static let boomerDiner = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color(red: 0.73, green: 0.12, blue: 0.16), Color(red: 0.92, green: 0.62, blue: 0.26), Color(red: 0.52, green: 0.16, blue: 0.2)],
            startPoint: .top,
            endPoint: .bottom
        ),
        accentA: Color(red: 0.99, green: 0.91, blue: 0.62),
        accentB: Color(red: 0.36, green: 0.83, blue: 0.72),
        stickerWords: ["daddy-o", "right on", "cool cat", "ace"],
        specialOverlay: AnyView(
            VStack {
                HStack(spacing: 0) {
                    ForEach(0..<14, id: \.self) { i in
                        Rectangle()
                            .fill(i.isMultiple(of: 2) ? Color.white.opacity(0.2) : Color.black.opacity(0.08))
                            .frame(height: 14)
                    }
                }
                Spacer()
            }
            .padding(.top, 70)
        )
    )
    
    static let parchmentDrama = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color(red: 0.62, green: 0.5, blue: 0.34), Color(red: 0.43, green: 0.29, blue: 0.18), Color(red: 0.24, green: 0.16, blue: 0.1)],
            startPoint: .top,
            endPoint: .bottom
        ),
        accentA: Color(red: 0.83, green: 0.67, blue: 0.42),
        accentB: Color(red: 0.51, green: 0.34, blue: 0.2),
        stickerWords: ["verily", "anon", "fate", "aye"],
        specialOverlay: AnyView(EmptyView())
    )
    
    static let gonzoDesert = WallpaperRecipe(
        baseGradient: LinearGradient(
            colors: [Color(red: 0.98, green: 0.47, blue: 0.08), Color(red: 0.73, green: 0.21, blue: 0.08), Color(red: 0.31, green: 0.05, blue: 0.07)],
            startPoint: .top,
            endPoint: .bottom
        ),
        accentA: Color(red: 0.98, green: 0.81, blue: 0.19),
        accentB: Color(red: 0.73, green: 0.12, blue: 0.21),
        stickerWords: ["chaos", "bats", "full throttle", "wave"],
        specialOverlay: AnyView(EmptyView())
    )
}

// Triangle window shape
struct TriangleWindow: View {
    let size: CGFloat
    let offset: CGSize
    let isShiny: Bool
    let content: AnyView

    init<Content: View>(size: CGFloat, offset: CGSize, isShiny: Bool = false, @ViewBuilder content: () -> Content) {
        self.size = size
        self.offset = offset
        self.isShiny = isShiny
        self.content = AnyView(content())
    }

    private var glowColor: Color {
        isShiny ? Color(red: 1.0, green: 0.82, blue: 0.25) : Color(red: 0.2, green: 0.6, blue: 1.0)
    }

    // Static gradients for better performance
    private var triangleGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: isShiny
                ? [Color(red: 1.0, green: 0.88, blue: 0.4), Color(red: 0.95, green: 0.65, blue: 0.1)]
                : [Color(red: 0.2, green: 0.6, blue: 1.0), Color(red: 0.1, green: 0.4, blue: 0.9)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func innerGlowGradient(size: CGFloat) -> RadialGradient {
        RadialGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(0.4),
                Color.white.opacity(0.1),
                Color.clear
            ]),
            center: .top,
            startRadius: size * 0.05,
            endRadius: size * 0.4
        )
    }
    
    private func edgeGlowGradient() -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(0.6),
                Color.white.opacity(0.2),
                Color.clear
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var body: some View {
        // Calculate padding needed to prevent triangle vertices from being clipped when offset
        // For an inverted triangle, the furthest points from center are the top corners
        // Diagonal distance from center to top corner: sqrt((size/2)^2 + (size/2)^2) = size * sqrt(2) / 2
        // We need extra space for the offset movement
        let triangleMaxRadius = size * sqrt(2) / 2
        let maxOffset = size * 0.15 // Maximum offset from updateGravityEffect
        let padding = triangleMaxRadius - size / 2 + maxOffset + 10 // Safety margin
        let containerSize = size + padding * 2

        // Text safe rectangle derived from triangle geometry:
        // Triangle is (0,0) - (size,0) - (size/2,size). Width shrinks linearly with y: width(y)=size-y.
        // If the rectangle's bottom is at yBottom, the rectangle width must be <= size - yBottom.
        let topInset = size * 0.035
        let safeHeight = size * 0.43
        let safeWidth = max(0, size - (topInset + safeHeight)) * 0.96 // tiny margin
        
        ZStack(alignment: .center) {
            // Blue triangle background (like classic Magic 8 Ball) with hazy edges
            // Centered in container, can move with offset
            Triangle()
                .fill(triangleGradient)
                .frame(width: size, height: size)
                .overlay(
                    // Inner glow effect
                    Triangle()
                        .fill(innerGlowGradient(size: size))
                        .frame(width: size, height: size)
                )
                .overlay(
                    // Hazy edge glow
                    Triangle()
                        .stroke(edgeGlowGradient(), lineWidth: 3)
                        .blur(radius: 2)
                        .frame(width: size, height: size)
                )
                .shadow(color: glowColor.opacity(isShiny ? 0.9 : 0.5), radius: isShiny ? 16 : 8, x: 0, y: 0)
                .offset(offset)
            
            // Content inside triangle:
            // Use a *guaranteed-inside* axis-aligned rectangle derived from triangle geometry.
            //
            // For this triangle: width(y) shrinks linearly from `size` at y=0 to 0 at y=size.
            // If we place a rectangle whose bottom is at yBottom, its width must be <= size - yBottom.
            VStack(spacing: 0) {
                Spacer().frame(height: topInset)
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    content
                        .frame(width: safeWidth, height: safeHeight, alignment: .top)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
            .frame(width: size, height: size, alignment: .top)
            .offset(offset)
        }
        .frame(width: containerSize, height: containerSize)
        // DO NOT use .clipped() here - it creates rectangular clipping
        .contentShape(Rectangle()) // Allow hit testing on full container
    }
}

/// A one-shot golden sparkle burst shown when a rare "shiny" fortune appears.
struct ShinyBurst: View {
    @State private var animate = false
    private let sparkleCount = 14

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let reach = min(geo.size.width, geo.size.height) * 0.5

            ZStack {
                // Expanding golden ring pulse
                Circle()
                    .stroke(Color(red: 1.0, green: 0.85, blue: 0.35), lineWidth: 3)
                    .frame(width: reach * 1.4, height: reach * 1.4)
                    .scaleEffect(animate ? 1.25 : 0.2)
                    .opacity(animate ? 0 : 0.9)
                    .position(center)

                // Radiating sparkles
                ForEach(0..<sparkleCount, id: \.self) { i in
                    let angle = Double(i) / Double(sparkleCount) * 2 * .pi
                    let dist = reach * (animate ? 1.0 : 0.05)
                    Image(systemName: "sparkle")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.9, blue: 0.5))
                        .shadow(color: Color(red: 1.0, green: 0.8, blue: 0.2).opacity(0.8), radius: 6)
                        .scaleEffect(animate ? 0.4 : 1.1)
                        .opacity(animate ? 0 : 1)
                        .position(
                            x: center.x + CGFloat(cos(angle)) * dist,
                            y: center.y + CGFloat(sin(angle)) * dist
                        )
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1)) { animate = true }
        }
    }
}

// Bubble model for particle effect
struct Bubble: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    var opacity: Double
}

// Custom circle shape for clipping at center of larger container
struct CircleShape: Shape {
    let radius: CGFloat
    let centerX: CGFloat
    let centerY: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // rect is the bounds of the view being clipped (containerSize x containerSize)
        // Create circle centered at (centerX, centerY) with given radius
        // The coordinates should be relative to rect, which starts at (0,0)
        let circleCenterX = centerX
        let circleCenterY = centerY
        let circleRect = CGRect(
            x: circleCenterX - radius,
            y: circleCenterY - radius,
            width: radius * 2,
            height: radius * 2
        )
        path.addEllipse(in: circleRect)
        return path
    }
}

// Triangle shape (wide part at top, like Magic 8 Ball - wider top)
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Wider part at top - triangle can extend fully to edges
        // Use full width for top to allow triangle to reach circle edge
        let topWidth = rect.width
        let leftOffset = (rect.width - topWidth) / 2
        path.move(to: CGPoint(x: rect.minX + leftOffset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - leftOffset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ContentView()
}
