//
//  AppIconSwitcher.swift
//  MeloNX
//
//  Created by Stossy11 on 02/06/2025.
//

import SwiftUI

struct AppIcon: Identifiable, Equatable {
    var id: String { creator }
    
    var iconNames: [String: String]
    var creator: String
}

struct AppIconSwitcherView: View {
    @Environment(\.dismiss) private var dismiss
    @State var appIcons: [AppIcon] = []
    
    @State var columns: [GridItem] = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    @State private var currentIconName: String? = nil
    @State var refresh = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground).opacity(0.95),
                        Color(.systemGroupedBackground)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 32) {
                        ForEach(appIcons.indices, id: \.self) { index in
                            let iconGroup = appIcons[index]
                            
                            VStack(alignment: .leading, spacing: 20) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(iconGroup.creator)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.primary)
                                        
                                        Text("\(iconGroup.iconNames.count) icons")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 24)
                                
                                LazyVGrid(columns: columns, spacing: 20) {
                                    ForEach(Array(iconGroup.iconNames.keys.sorted()), id: \.self) { key in
                                        if let iconName = iconGroup.iconNames[key] {
                                            Button {
                                                selectIcon(iconName)
                                            } label: {
                                                ZStack {
                                                    AppIconView(app: (iconName, key))
                                                    
                                                    if iconName == currentIconName ?? UIImage.appIcon() {
                                                        VStack {
                                                            HStack {
                                                                Spacer()
                                                                Image(systemName: "checkmark.circle.fill")
                                                                    .font(.system(size: 24, weight: .bold))
                                                                    .foregroundStyle(.white)
                                                                    .background(
                                                                        Circle()
                                                                            .fill(
                                                                                LinearGradient(
                                                                                    colors: [.blue, .purple],
                                                                                    startPoint: .topLeading,
                                                                                    endPoint: .bottomTrailing
                                                                                )
                                                                            )
                                                                            .frame(width: 28, height: 28)
                                                                    )
                                                            }
                                                            Spacer()
                                                        }
                                                        .frame(width: 80, height: 80)
                                                        .offset(x: 6, y: -6)
                                                    }
                                                }
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .scaleEffect(isCurrentIcon(iconName) ? 0.95 : 1.0)
                                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCurrentIcon(iconName))
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                            
                            // Stylized divider
                            if index < appIcons.count - 1 {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.clear, Color(.separator), .clear],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 1)
                                    .padding(.horizontal, 40)
                            }
                        }
                    }
                    .padding(.vertical, 32)
                }
            }
            .navigationTitle("Choose App Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
                }
            }
        }
        .onAppear(perform: setupColumns)
        .onAppear(perform: getCurrentIconName)
    }
    
    private func setupColumns() {
        if #available(iOS 19, *) {
            appIcons = [
                AppIcon(iconNames: ["Default": UIImage.appIcon(), "Round": "RoundAppIcon"], creator: "CycloKid (Liquid Glass by Transistor)"),
                AppIcon(iconNames: ["Pixel Default": "PixelAppIcon", "Pixel Round": "PixelRoundAppIcon"], creator: "Nobody (Liquid Glass by Transistor)"),
                AppIcon(iconNames: ["\"UwU\"": "uwuAppIcon"], creator: "𝒰𝓃𝓀𝓃𝑜𝓌𝓃 (Liquid Glass by Transistor)"),
            ]
        } else {
            appIcons = [
                AppIcon(iconNames: ["Default": UIImage.appIcon(), "Dark Mode": "DarkMode", "Round": "RoundAppIcon"], creator: "CycloKid"),
                AppIcon(iconNames: ["Pixel Default": "PixelAppIcon", "Pixel Round": "PixelRoundAppIcon"], creator: "Nobody"),
                AppIcon(iconNames: ["\"UwU\"": "uwuAppIcon"], creator: "𝒰𝓃𝓀𝓃𝑜𝓌𝓃"),
            ]
        }
        
        appIcons.append(contentsOf: [
            AppIcon(iconNames: [(isAvailable(iOS: 19) ? "Clear" : "Clear (Liquid Glass)"): "Clear", "Mel-o-Lantern": "Mel-o-Lantern", "MeloNXmas": "MeloNXmas", "MeluckyNX \n (Saint Patrick's Day)": "MeluckyNX"], creator: "Transistor"),
            AppIcon(iconNames: ["MellowSkyNX": "MellowSkyNX"], creator: "Sky (@dootskyre)"),
            AppIcon(iconNames: ["Skeuomorphic": "skeuomorphic"], creator: "@stars33k")
        ])
    }
    
    private func getCurrentIconName() {
        currentIconName = UIApplication.shared.alternateIconName ?? UIImage.appIcon()
    }
    
    private func isCurrentIcon(_ iconName: String) -> Bool {
        let currentIcon = UIApplication.shared.alternateIconName ?? UIImage.appIcon()
        return currentIcon == iconName
    }
    
    private func selectIcon(_ iconName: String) {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        if iconName == UIImage.appIcon() {
            UIApplication.shared.setAlternateIconName(nil) { error in
                if let error = error {
                    print("Error setting icon: \(error)")
                } else {
                   Task { @MainActor in
                        currentIconName = nil
                        refresh = Int.random(in: 0...100)
                    }
                }
            }
        } else {
            UIApplication.shared.setAlternateIconName(iconName) { error in
                if let error = error {
                    print("Error setting icon: \(error)")
                } else {
                   Task { @MainActor in
                        currentIconName = iconName
                        refresh = Int.random(in: 0...100)
                    }
                }
            }
        }
    }
    
    func isAvailable(iOS version: Int) -> Bool {
        let current = ProcessInfo.processInfo.operatingSystemVersion
        return current.majorVersion >= version
    }

}

struct AppIconView: View {
    let app: (String, String)
    
    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                if let iconImage = UIImage(named: app.0) {
                    Image(uiImage: iconImage)
                        .resizable()
                        .cornerRadius(15)
                        .frame(width: 62, height: 62)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                } else {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 62, height: 62)
                        .overlay(
                            Image(systemName: "app.dashed")
                                .foregroundColor(.gray)
                        )
                }
            }
            
            Text(app.1)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                .frame(width: app.1.contains("\n") ? 150 : 100)
                .lineLimit(app.1.contains("\n") ? 2 : 1)
        }
    }
}
extension UIImage {
    static func appIcon() -> String {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return lastIcon
        }
        return "AppIcon"
    }
}
