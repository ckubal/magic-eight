//
//  SettingsView.swift
//  magic eight
//
//  Created by Charlie Kubal on 12/1/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var responseManager: ResponseManager
    @Environment(\.dismiss) var dismiss
    var onReturnToOpening: (() -> Void)? = nil
    @AppStorage("ballSkin") private var ballSkinRaw = "classic"
    @AppStorage("shinyFortuneCount") private var shinyCount = 0
    @AppStorage("screenFXEnabled") private var screenFXEnabled = true
    
    private let privacyPolicyURLString = "https://weirdlittleideas.com/magic-eight/privacy.html"
    private let termsOfUseURLString = "https://weirdlittleideas.com/magic-eight/tos.html"
    private let supportEmail = "weirdlittleideas@gmail.com"
    
    private var privacyPolicyURL: URL? {
        guard !privacyPolicyURLString.isEmpty else { return nil }
        return URL(string: privacyPolicyURLString)
    }
    
    private var termsOfUseURL: URL? {
        guard !termsOfUseURLString.isEmpty else { return nil }
        return URL(string: termsOfUseURLString)
    }
    
    private var appVersionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "n/a"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "n/a"
        return "\(version) (\(build))"
    }
    
    private var setsByCategory: [ResponseSetCategory: [ResponseSet]] {
        Dictionary(grouping: responseManager.availableSets) { $0.category }
    }
    
    private let categoryDisplayOrder: [ResponseSetCategory] = [
        .styles,
        .techEras,
        .popCulture,
        .generations
    ]
    
    private let setOrderByCategory: [ResponseSetCategory: [String]] = [
        .styles: ["classic", "shakespearean", "huntersthompson"],
        // Earliest to latest
        .techEras: [
            "aimy2k",
            "xanga2002",
            "myspace2005",
            "deviantart2006",
            "facebook2008",
            "tumblr2012",
            "tiktok2020",
            "twitterx2024"
        ],
        .popCulture: ["harrypotter", "matrix", "nbajam", "sportscenter"],
        .generations: ["boomers1958", "genx", "millennial", "genz", "genalpha"]
    ]
    
    private func orderedSets(for category: ResponseSetCategory) -> [ResponseSet] {
        let sets = setsByCategory[category] ?? []
        let order = setOrderByCategory[category] ?? []
        let indexById = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        
        return sets.sorted { lhs, rhs in
            let lhsIndex = indexById[lhs.id]
            let rhsIndex = indexById[rhs.id]
            
            switch (lhsIndex, rhsIndex) {
            case let (l?, r?):
                return l < r
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: {
                        responseManager.selectedSetId = "random"
                        dismiss()
                    }) {
                        HStack {
                            Text("🎲")
                                .font(.title2)
                            Text("random")
                                .foregroundColor(.primary)
                            Spacer()
                            if responseManager.selectedSetId == "random" {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                ForEach(categoryDisplayOrder, id: \.self) { category in
                    let sets = orderedSets(for: category)
                    if !sets.isEmpty {
                        let hasLocked = sets.contains { !responseManager.isThemeUnlocked($0.id, shinyCount: shinyCount) }
                        Section {
                            ForEach(sets) { set in
                                let unlocked = responseManager.isThemeUnlocked(set.id, shinyCount: shinyCount)
                                Button(action: {
                                    guard unlocked else { return }
                                    responseManager.selectedSetId = set.id
                                    dismiss()
                                }) {
                                    HStack {
                                        Text(set.emoji)
                                            .font(.title2)
                                            .opacity(unlocked ? 1 : 0.45)
                                        Text(set.name.lowercased())
                                            .foregroundColor(unlocked ? .primary : .secondary)
                                        Spacer()
                                        if !unlocked {
                                            HStack(spacing: 3) {
                                                Image(systemName: "lock.fill")
                                                Text("\(responseManager.themeUnlockThreshold(set.id))✨")
                                            }
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.secondary)
                                        } else if responseManager.selectedSetId == set.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .disabled(!unlocked)
                            }
                        } header: {
                            Text(category.rawValue)
                        } footer: {
                            if hasLocked {
                                Text("🔒 bonus themes unlock as you collect rare shiny fortunes (you've found \(shinyCount)).")
                            }
                        }
                    }
                }
                
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            ForEach(BallSkin.allCases) { skin in
                                let unlocked = skin.isUnlocked(shinyCount: shinyCount)
                                Button(action: {
                                    guard unlocked else { return }
                                    ballSkinRaw = skin.rawValue
                                }) {
                                    VStack(spacing: 6) {
                                        skin.sphere(size: 52)
                                            .frame(width: 52, height: 52)
                                            .overlay(
                                                Circle().stroke(
                                                    ballSkinRaw == skin.rawValue ? Color.blue : Color.clear,
                                                    lineWidth: 3
                                                )
                                            )
                                            .overlay {
                                                if !unlocked {
                                                    Circle().fill(Color.black.opacity(0.55))
                                                    Image(systemName: "lock.fill")
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(.white.opacity(0.9))
                                                }
                                            }
                                        Text(unlocked ? skin.title : "\(skin.requiredShinies)✨")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(ballSkinRaw == skin.rawValue ? .primary : .secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                } header: {
                    Text("ball skin")
                } footer: {
                    Text("locked skins open up as you collect rare shiny fortunes (\(shinyCount) found so far).")
                }

                Section {
                    Toggle(isOn: $screenFXEnabled) {
                        HStack {
                            Text("📺")
                            Text("retro screen effects")
                        }
                    }
                } header: {
                    Text("extras")
                } footer: {
                    Text("adds era-authentic scanlines, tape grain, and pixel grids to the retro themes.")
                }

                if onReturnToOpening != nil {
                    Section {
                        Button(action: {
                            onReturnToOpening?()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.secondary)
                                Text("return to opening")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("about") {
                    HStack {
                        Text("app version")
                        Spacer()
                        Text(appVersionLabel)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("legal") {
                    if let termsOfUseURL {
                        Link("terms of service", destination: termsOfUseURL)
                    }
                    if let privacyPolicyURL {
                        Link("privacy policy", destination: privacyPolicyURL)
                    }
                    Link("contact support", destination: URL(string: "mailto:\(supportEmail)")!)
                }
                
                // Footer
                Section {
                    EmptyView()
                } footer: {
                    Text("magic eight is a project by weird little ideas, llc.")
                        .font(.system(size: 12, weight: .light, design: .default))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .navigationTitle("settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Refresh remote updates when settings view appears (non-blocking)
                responseManager.checkForRemoteUpdates()
            }
        }
    }
}

#Preview {
    SettingsView(responseManager: ResponseManager(), onReturnToOpening: nil)
}

