//
//  GamesListAirplay.swift
//  MeloNX
//
//  Created by Stossy11 on 13/11/2025.
//

import SwiftUI
import GameController

struct GamesListAirplay: View {
    @State private var selectedIndex = 0
    @EnvironmentObject var gameHandler: LaunchGameHandler
    @ObservedObject private var ryujinx = Ryujinx.shared
    
    @State var previousDpadHandlers: [GCController: GCControllerDirectionPadValueChangedHandler?] = [:]
    @State var previousButtonAHandlers: [GCController: GCControllerButtonValueChangedHandler?] = [:]


    var body: some View {
        ScrollViewReader { proxy in
            List(ryujinx.games.indices, id: \.self) { index in
                let game = ryujinx.games[index]

                HStack(spacing: 16) {
                    Group {
                        if let icon = game.icon {
                            Image(uiImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .frame(width: 55, height: 55)
                    .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.titleName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)

                        HStack(spacing: 4) {
                            Text(game.developer)

                            if !game.version.isEmpty && game.version != "0" {
                                Text("•")
                                Text("v\(game.version)")
                            }
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .background(selectedIndex == index ? Color.blue.opacity(0.3) : .clear)
                .id(index)
            }
            .onChange(of: selectedIndex) { newIndex in
                withAnimation {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
            .onAppear {
                setupControllerObservers(scrollProxy: proxy)
            }
        }
    }

    private func setupControllerObservers(scrollProxy: ScrollViewProxy) {
        let dpadHandler: GCControllerDirectionPadValueChangedHandler = { _, _, yValue in
            if yValue == 1.0 {
                selectedIndex = max(0, selectedIndex - 1)
            } else if yValue == -1.0 {
                selectedIndex = min(ryujinx.games.count - 1, selectedIndex + 1)
            }
        }

        for controller in GCController.controllers() {
            print("Controller connected: \(controller.vendorName ?? "Unknown")")
            controller.playerIndex = .index1
            
            
            previousDpadHandlers[controller] = controller.extendedGamepad?.dpad.valueChangedHandler
            previousButtonAHandlers[controller] = controller.extendedGamepad?.buttonA.pressedChangedHandler

            controller.microGamepad?.dpad.valueChangedHandler = dpadHandler
            controller.extendedGamepad?.dpad.valueChangedHandler = dpadHandler

            controller.extendedGamepad?.buttonA.pressedChangedHandler = { _, _, pressed in
                if pressed {
                    print("A button pressed")
                    gameHandler.currentGame = ryujinx.games[selectedIndex]
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { _ in
            setupControllerObservers(scrollProxy: scrollProxy)
        }
    }
    
    private func revertButtonAHandler() {
        for controller in GCController.controllers() {
            if let extended = controller.extendedGamepad {
                controller.microGamepad?.dpad.valueChangedHandler = previousDpadHandlers[controller] ?? nil
                controller.extendedGamepad?.dpad.valueChangedHandler = previousDpadHandlers[controller] ?? nil
                extended.buttonA.pressedChangedHandler = previousButtonAHandlers[controller] ?? nil
            }
        }

        NotificationCenter.default.removeObserver(
            self,
            name: .GCControllerDidConnect,
            object: nil
        )
    }
}
