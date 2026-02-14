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
                ForEach(categoryDisplayOrder, id: \.self) { category in
                    let sets = orderedSets(for: category)
                    if !sets.isEmpty {
                        Section(header: Text(category.rawValue)) {
                            ForEach(sets) { set in
                                Button(action: {
                                    responseManager.selectedSetId = set.id
                                    dismiss()
                                }) {
                                    HStack {
                                        Text(set.emoji)
                                            .font(.title2)
                                        Text(set.name.lowercased())
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if responseManager.selectedSetId == set.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
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
    SettingsView(responseManager: ResponseManager())
}

