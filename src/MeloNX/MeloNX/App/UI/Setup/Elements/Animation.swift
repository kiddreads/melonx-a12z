//
//  Animation.swift
//  MeloNX
//
//  Created by Stossy11 on 8/2/2026.
//

import Foundation
import SwiftUI

struct IconAnimation: View {
    @State private var isRotating = 0.0
    @Binding var showMainSetup: Bool
    var body: some View {
        Image(uiImage: UIImage(named: appIcon()) ?? UIImage())
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 40))
            .overlay(
                RoundedRectangle(cornerRadius: 40)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .blue.opacity(0.6),
                                .red.opacity(0.6)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 6)
            .rotationEffect(.degrees(180))
            .rotationEffect(.degrees(isRotating))
            .onAppear {
                withAnimation(.linear(duration: 0.6).speed(0.9)) {
                    isRotating = 180
                    
                    Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
                        withAnimation(.easeOut) {
                            showMainSetup = true
                        }
                    }
                }
            }
    }
    
    func appIcon(in bundle: Bundle = .main) -> String {
        guard let icons = bundle.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              
              let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
              
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
              
              let iconFileName = iconFiles.last else {

            // print("Could not find icons in bundle")
            return ""
        }

        return iconFileName
    }
}
