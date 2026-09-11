//
//  GameRowView.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import SwiftUI

struct GameRowView: View {
    let game: Game
    @Binding var selectedGame: Game?
    @Binding var games: [Game]
    @EnvironmentObject var gameHandler: LaunchGameHandler
    @Binding var gameRequirements: [GameRequirements]
    @StateObject private var settingsManager = PerGameSettingsManager.shared
    @State var gametoDelete: Game?
    @State var showGameDeleteConfirmation: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.verticalSizeClass) var verticalSizeClass: UserInterfaceSizeClass?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass: UserInterfaceSizeClass?
    
    @AppStorage("portal") var gamepo = false
    
    var body: some View {
        Button(action: {
            gameHandler.currentGame = game
        }) {
            HStack(spacing: 16) {
                // Game Icon
                if let icon = game.icon {
                    Image(uiImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 55, height: 55)
                        .cornerRadius(10)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ?
                                  Color(.systemGray5) : Color(.systemGray6))
                            .frame(width: 55, height: 55)
                        
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
                
                // Game Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.titleName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(game.developer)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        
                        if !game.version.isEmpty && game.version != "0" {
                            Divider().frame(width: 1, height: 15)
                            
                            Text("v\(game.version)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if $settingsManager.config.wrappedValue.contains(where: { $0.key == game.titleId }) {
                    Image(systemName: "gearshape.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .foregroundStyle(.blue)
                        .frame(width: 20, height: 20)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    // Compatibility badges
                    HStack {
                        if let gameReq = gameRequirements.first(where: { $0.game_id == game.titleId }) {
                            let totalMemory = ProcessInfo.processInfo.physicalMemory
                            
                            HStack(spacing: 4) {
                                Text(gameReq.device_memory)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(gameReq.memoryInt <= Int(String(format: "%.0f", Double(totalMemory) / 1_000_000_000)) ?? 0 ? Color.blue : Color.red)
                                    )
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .layoutPriority(1)
                                
                                Text(gameReq.compatibility)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(gameReq.color)
                                    )
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .layoutPriority(1)
                            }
                        }
                        
                        // Play button
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .confirmationDialog("Are you sure you want to delete this game?", isPresented: $showGameDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let game = gametoDelete {
                    deleteGame(game: game)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(gametoDelete?.titleName ?? "this game")?")
        }
        .listRowInsets(EdgeInsets())
        .liquidGlass(selectedGame: $selectedGame, game: game) {
            if selectedGame != nil, selectedGame?.id == game.id {
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? .blue.opacity(0.5) : .blue)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6).opacity(0.5))
            }
        }
        
    }
    
    private func deleteGame(game: Game) {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(at: game.fileURL)
            games.removeAll { $0.id == game.id }
        } catch {
            // print("Error deleting game: \(error)")
        }
    }
}

extension View {
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = 12, interactive: Bool = true, background: @escaping () -> some View) -> some View {
        if #available(iOS 19, *), !NativeSettingsManager.shared.disableLiquidGlass.value {
            self.glassEffect(interactive ? .regular.tint(Color(.systemGray6)).interactive() : .regular.tint(Color(.systemGray6)), in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            self
                .background(
                    background()
                )
        }
    }
    
    
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = 12, selectedGame: Binding<Game?>, game: Game, background: @escaping () -> some View) -> some View {
        if #available(iOS 19, *), !NativeSettingsManager.shared.disableLiquidGlass.value {
            if selectedGame.wrappedValue != nil, selectedGame.wrappedValue?.id == game.id {
                self.glassEffect(.regular.tint(.blue.opacity(0.5)).interactive(), in: RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                self.glassEffect(.regular.tint(Color(.systemGray6)).interactive(), in: RoundedRectangle(cornerRadius: cornerRadius))
            }
        } else {
             self
                .background(
                    background()
                )
        }
    }
}
