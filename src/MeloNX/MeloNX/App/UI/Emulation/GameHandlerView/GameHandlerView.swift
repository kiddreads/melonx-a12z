//
//  LoadingView.swift
//  MeloNX
//
//  Created by Stossy11 on 23/09/2025.
//

import SwiftUI

struct EmulationContainerView: View {
    @EnvironmentObject var gameHandler: LaunchGameHandler
    @State private var showing: Bool = false
    // var startEmulationCallback: () -> Void
    
    @AppStorage("showlogsloading") var showlogsloading: Bool = false
    
    @State private var loadingID = UUID()
    
    var body: some View {
        ZStack {
            if #available(iOS 16, *) {
                EmulationView()
                    .persistentSystemOverlays(.hidden)
            } else {
                EmulationView()
            }
            
            LoadingOverlayView(
                game: gameHandler.currentGame,
                showLogs: showlogsloading,
                startEmulationCallback: {
                    gameHandler.startGame()
                }
            )
            .id(loadingID)
        }

    }
}
