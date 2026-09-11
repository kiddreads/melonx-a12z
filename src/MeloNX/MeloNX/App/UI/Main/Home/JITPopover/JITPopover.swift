//
//  JITPopover.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import SwiftUI

struct JITPopover: View {
    var onJITEnabled: () -> Void
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var gameHandler: LaunchGameHandler
    
    @State private var isJIT: Bool = false
    @State private var pulseAnimation: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // cool animation :3
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .opacity(pulseAnimation ? 0 : 1)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: pulseAnimation
                    )
                
                Image(systemName: "cpu.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }
            .padding(.top, 10)
            
            VStack(spacing: 8) {
                Text("Waiting for JIT")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Waiting for Just-In-Time compilation...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                    
                    Text("JIT compilation enables MeloNX to achieve maximum performance by dynamically translating and executing code on the fly.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                    
                    Text("This process is required for the emulator to function properly.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .padding(24)
        .frame(maxWidth: 400)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
        .onAppear {
            pulseAnimation = true
            
            gameHandler.enableJIT()
            
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                isJIT = isJITEnabled()
                
                if isJIT {
                    timer.invalidate()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    onJITEnabled()
                    Ryujinx.shared.checkForJIT()
                }
            }
        }
    }
}
