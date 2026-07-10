//
//  DecadeDial.swift
//  magic eight
//
//  Phase 6.1 — the decade dial. Switching eras is a ritual, not a menu:
//  a horizontal tuner you drag through detents. Each detent ticks with a
//  haptic and live-morphs the whole app into that era.
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

    @State private var dragAccumulator: CGFloat = 0
    private let detentWidth: CGFloat = 56
    private let tick = UIImpactFeedbackGenerator(style: .rigid)

    private var currentIndex: Int {
        themes.firstIndex(where: { $0.id == currentId }) ?? 0
    }

    var body: some View {
        VStack(spacing: 6) {
            // The tuner strip: neighbors fade out to the sides.
            HStack(spacing: 14) {
                ForEach(visibleSlots(), id: \.offset) { slot in
                    slotView(slot.theme, distance: slot.offset)
                        .onTapGesture {
                            guard slot.offset != 0 else { return }
                            step(by: slot.offset)
                        }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.55))
                    .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let delta = value.translation.width - dragAccumulator
                        if abs(delta) >= detentWidth {
                            // Drag right = spin back in time (previous era).
                            step(by: delta < 0 ? 1 : -1)
                            dragAccumulator = value.translation.width
                        }
                    }
                    .onEnded { _ in dragAccumulator = 0 }
            )

            // Needle + hint
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))
                .offset(y: -4)
            Text("drag to tune the era")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .offset(y: -6)
        }
    }

    // MARK: - Slots

    private struct Slot {
        let offset: Int
        let theme: DialTheme?
    }

    /// Five slots centered on the current selection: [-2, -1, 0, +1, +2],
    /// wrapping around the ends so the dial spins forever.
    private func visibleSlots() -> [Slot] {
        guard !themes.isEmpty else { return [] }
        return (-2...2).map { offset in
            let idx = ((currentIndex + offset) % themes.count + themes.count) % themes.count
            return Slot(offset: offset, theme: themes[idx])
        }
    }

    @ViewBuilder
    private func slotView(_ theme: DialTheme?, distance: Int) -> some View {
        let isCenter = distance == 0
        VStack(spacing: 2) {
            Text(theme?.emoji ?? "")
                .font(.system(size: isCenter ? 26 : 18))
            if isCenter {
                Text(theme?.name.lowercased() ?? "")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .opacity(isCenter ? 1.0 : (abs(distance) == 1 ? 0.55 : 0.28))
        .scaleEffect(isCenter ? 1.0 : 0.85)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: currentId)
    }

    private func step(by delta: Int) {
        guard !themes.isEmpty else { return }
        let next = ((currentIndex + delta) % themes.count + themes.count) % themes.count
        tick.impactOccurred(intensity: 0.8)
        onSelect(themes[next].id)
    }
}
