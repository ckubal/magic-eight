//
//  DecadeDial.swift
//  magic eight
//
//  Phase 6.1 — the decade dial. A smooth horizontal tuner: emojis scroll
//  continuously under your finger and snap to center; the centered era is
//  the selection and live-morphs the whole app.
//

import SwiftUI
import UIKit

struct DialTheme: Identifiable, Equatable {
    let id: String
    let emoji: String
    let name: String
}

struct DecadeDial: View {
    let themes: [DialTheme]
    let currentId: String
    let onSelect: (String) -> Void

    @State private var scrollId: String?
    private let tick = UIImpactFeedbackGenerator(style: .soft)
    private let itemWidth: CGFloat = 52

    private var currentName: String {
        themes.first(where: { $0.id == currentId })?.name.lowercased() ?? ""
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let sideInset = max(0, (geo.size.width - itemWidth) / 2)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(themes) { theme in
                            Text(theme.emoji)
                                .font(.system(size: 28))
                                .frame(width: itemWidth, height: 44)
                                .scrollTransition(axis: .horizontal) { content, phase in
                                    content
                                        .opacity(phase.isIdentity ? 1.0 : 0.35)
                                        .scaleEffect(phase.isIdentity ? 1.2 : 0.78)
                                }
                                .id(theme.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, sideInset, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $scrollId, anchor: .center)
                // A soft spotlight marking the centered slot.
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                        .frame(width: itemWidth + 6, height: 46)
                        .allowsHitTesting(false)
                )
            }
            .frame(height: 48)

            Text(currentName)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .animation(.easeInOut(duration: 0.2), value: currentName)
        }
        .frame(maxWidth: 300)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.55))
                .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
        )
        .onAppear { scrollId = currentId }
        .onChange(of: scrollId) { _, newValue in
            guard let newValue, newValue != currentId else { return }
            tick.impactOccurred(intensity: 0.6)
            onSelect(newValue)
        }
        .onChange(of: currentId) { _, newValue in
            guard scrollId != newValue else { return }
            withAnimation(.easeInOut(duration: 0.25)) { scrollId = newValue }
        }
    }
}
