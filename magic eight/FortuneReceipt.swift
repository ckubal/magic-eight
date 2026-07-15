//
//  FortuneReceipt.swift
//  magic eight
//
//  Phase 5 — the shareable fortune "receipt": a dot-matrix style printout of
//  the answer, rendered to an image for the share sheet.
//

import SwiftUI
import UIKit

struct FortuneReceiptView: View {
    let themeName: String
    let answer: String
    let date: Date
    let isShiny: Bool

    private var stamp: String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd/yyyy  HH:mm"
        return f.string(from: date)
    }

    private var paper: Color { Color(red: 0.98, green: 0.97, blue: 0.93) }
    private var ink: Color { Color(red: 0.18, green: 0.17, blue: 0.16) }
    private var accent: Color {
        isShiny ? Color(red: 0.72, green: 0.55, blue: 0.05) : ink
    }

    private func dashes() -> some View {
        Text(String(repeating: "- ", count: 22))
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            .foregroundColor(ink.opacity(0.55))
            .lineLimit(1)
    }

    // Fake barcode: deterministic bars from the answer text.
    private var barWidths: [CGFloat] {
        answer.unicodeScalars.prefix(28).map { CGFloat($0.value % 4) + 1.5 }
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("★ magic eight ★")
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .kerning(2)
            Text("official fortune receipt")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(ink.opacity(0.7))

            dashes()

            HStack {
                Text("date")
                Spacer()
                Text(stamp)
            }
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            HStack {
                Text("era")
                Spacer()
                Text(themeName.lowercased())
            }
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            HStack {
                Text("method")
                Spacer()
                Text("one (1) phone flip")
            }
            .font(.system(size: 12, weight: .regular, design: .monospaced))

            dashes()

            Text("the ball says:")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(ink.opacity(0.7))
                .padding(.top, 4)

            Text(answer.lowercased())
                .font(.system(size: 26, weight: .black, design: .monospaced))
                .foregroundColor(accent)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

            if isShiny {
                Text("✨ rare shiny fortune ✨")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(accent)
            }

            dashes()

            // Barcode footer
            HStack(alignment: .bottom, spacing: 2.5) {
                ForEach(Array(barWidths.enumerated()), id: \.offset) { _, w in
                    Rectangle()
                        .fill(ink)
                        .frame(width: w, height: 30)
                }
            }
            .padding(.top, 2)

            Text("no refunds • no exchanges")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(ink.opacity(0.6))
            Text("ask again soon")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(ink.opacity(0.6))

            // Barely-there maker's mark.
            Text("a weird little idea · by charlie kubal")
                .font(.system(size: 6, weight: .regular, design: .monospaced))
                .foregroundColor(ink.opacity(0.3))
                .padding(.top, 6)
        }
        .foregroundColor(ink)
        .padding(.vertical, 26)
        .padding(.horizontal, 22)
        .frame(width: 320)
        .background(paper)
    }
}

enum FortuneReceiptRenderer {
    @MainActor
    static func image(themeName: String, answer: String, isShiny: Bool) -> UIImage? {
        let view = FortuneReceiptView(
            themeName: themeName,
            answer: answer,
            date: Date(),
            isShiny: isShiny
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}

enum ShareSheetPresenter {
    /// Present the system share sheet directly from the top-most view
    /// controller. Presenting UIActivityViewController this way avoids the
    /// blank-sheet bug you hit when it's nested inside a SwiftUI `.sheet`.
    @MainActor
    static func present(_ items: [Any]) {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard let root = (scene?.keyWindow ?? scene?.windows.first)?.rootViewController else { return }

        var top = root
        while let presented = top.presentedViewController { top = presented }

        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // iPad needs a popover anchor.
        if let pop = vc.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 60, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        top.present(vc, animated: true)
    }
}
