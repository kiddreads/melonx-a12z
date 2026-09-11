//
//  GameCardView.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import SwiftUI


struct GameCardView: View {
    @EnvironmentObject var gameHandler: LaunchGameHandler
    @StateObject private var settingsManager = PerGameSettingsManager.shared
    @StateObject var nativeSettings = NativeSettingsManager.shared
    let game: Game
    @Binding var games: [Game]
    @Binding var gameRequirements: [GameRequirements]
    @Environment(\.colorScheme) var colorScheme
    let totalMemory = ProcessInfo.processInfo.physicalMemory
    var cardType: CardType {
        nativeSettings.cardLayout(CardType.card).value
    }
    var gameRequirement: GameRequirements? {
        gameRequirements.first(where: { $0.game_id == game.titleId })
    }
    
    @ViewBuilder
    var smallGrid: some View {
        if let icon = game.icon {
            Image(uiImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                .frame(width: 150, height: 150)
            
            Image(systemName: "questionmark.square.dashed")
                .font(.system(size: 40))
                .foregroundColor(.gray)
        }
    }
    
    @ViewBuilder
    var wiiUCard: some View {
        Group {
            if let icon = game.icon {
                Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 95, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                    .frame(width: 95, height: 95)
                
                Image(systemName: "questionmark.square.dashed")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            }
        }
        .padding(10)
        .liquidGlass(cornerRadius: 20) {
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, x: 0, y: 2)
        }
    }
    
    var body: some View {
        Button {
            gameHandler.currentGame = game
        } label: {
            if cardType == .compactCard || cardType == .compactCardNoBackground {
                smallGrid
                    .if(cardType == .compactCard) { view in
                        view
                            .padding(12)
                            .liquidGlass(cornerRadius: 16) {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, x: 0, y: 2)
                            }
                    }
            } else if cardType == .compactCardSmall {
                wiiUCard
            } else {
                normalGrid
            }
        }
    }
    
    
    @ViewBuilder
    var normalGrid: some View {
        VStack(spacing: 8) {
            // Game Icon
            ZStack {
                if let icon = game.icon {
                    Image(uiImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                        .frame(width: 150, height: 150)
                    
                    Image(systemName: "questionmark.square.dashed")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
                
                // Play button overlay
                Button {
                    gameHandler.currentGame = game
                } label: {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .offset(x: 2)
                        )
                }
            }
            
            // Game info
            VStack(alignment: .leading, spacing: 4) {
                Text(game.titleName)
                    .font(.system(size: 14, weight: .semibold))
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Text(game.developer)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if $settingsManager.config.wrappedValue.contains(where: { $0.key == game.titleId }) {
                        Image(systemName: "gearshape.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .foregroundStyle(.blue)
                            .frame(width: 12, height: 12)
                    }
                }
                
                // Compatibility tag
                if let req = gameRequirement {
                    HStack(spacing: 4) {
                        Text(req.compatibility)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(req.color)
                            .cornerRadius(4)
                        
                        Text(req.device_memory)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(req.memoryInt <= Int(String(format: "%.0f", Double(totalMemory) / 1_000_000_000)) ?? 0 ? Color.blue : Color.red)
                            .cornerRadius(4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .padding(12)
        .frame(width: 174, height: 220)
        .liquidGlass(cornerRadius: 16) {
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
