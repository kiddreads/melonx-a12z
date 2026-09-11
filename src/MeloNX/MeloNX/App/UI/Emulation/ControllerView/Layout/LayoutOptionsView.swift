//
//  LayoutOptionsView.swift
//  MeloNX
//
//  Created by Stossy11 on 26/1/2026.
//

import SwiftUI

struct LayoutOptionsView: View {
    let gameId: String?
    @Binding var layout: LayoutConfig
    @Environment(\.presentationMode) var presentationMode
    @State private var showingResetAlert = false
    @State private var showingCopySheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let gameId = gameId {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Game")
                            .font(.headline)
                        HStack {
                            Image(systemName: "gamecontroller.fill")
                                .foregroundColor(.blue)
                            Text(gameId)
                                .font(.subheadline)
                            Spacer()
                            if LayoutManager.shared.hasCustomLayout(for: gameId) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Custom Layout")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            } else {
                                Text("Using Default")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Layout Actions")
                        .font(.headline)
                    
                    Button(action: {
                        showingCopySheet = true
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Layout From...")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        layout = LayoutManager.shared.load(for: nil)
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Reset to Default Layout")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        showingResetAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Custom Layout")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Layout Options")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .alert("Delete Custom Layout", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                LayoutManager.shared.reset(for: gameId)
                layout = LayoutManager.shared.load(for: gameId)
            }
        } message: {
            Text("This will delete the custom layout for this game and revert to the default layout.")
        }
        .sheet(isPresented: $showingCopySheet) {
            CopyLayoutView(targetGameId: gameId, layout: $layout)
        }
    }
}
