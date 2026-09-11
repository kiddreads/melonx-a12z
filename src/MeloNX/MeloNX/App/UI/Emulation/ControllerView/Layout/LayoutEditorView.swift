//
//  LayoutEditorView.swift
//  MeloNX
//
//  Created by Stossy11 on 26/1/2026.
//

import SwiftUI

class JoystickDPadUIHandler: ObservableObject {
    @Published var gameId: String?
    @Published var uiUpdate = false
    var joystickDpad: Bool {
        get {
            uiUpdate.toggle()
            return UserDefaults.standard.bool(forKey: "joystickDpad-\(gameId, default: "global")")
        } set {
            UserDefaults.standard.set(newValue, forKey: "joystickDpad-\(gameId, default: "global")")
            uiUpdate.toggle()
        }
    }
}

struct LayoutEditorView: View {
    @AppStorage("On-ScreenControllerScale") private var controllerScale: Double = 1.0
    @AppStorage("stickButton") private var stickButton = false
    @StateObject var joystickDpad = JoystickDPadUIHandler()
    @EnvironmentObject var gameHandler: LaunchGameHandler
    @Binding var hideDpad: Bool
    @Binding var hideABXY: Bool
    @Binding var isEditing: Bool
    @State private var selectedButton: String?
    @State private var selectedJoystick: String?
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Binding var showEditControls: Bool
    
    var gameId: String?
    @Binding var layout: LayoutConfig
    @State private var showingLayoutOptions = false
    
    private func loadLayout() {
        joystickDpad.gameId = gameId
        layout = LayoutManager.shared.load(for: gameId)
        
        let legacyLayout = LayoutManager.shared.loadLegacy(for: gameId)
        if !legacyLayout.isEmpty && layout.buttons.isEmpty {
            layout.buttons = legacyLayout
            LayoutManager.shared.save(layout, for: gameId)
        }
    }
    
    
    private func saveLayout() {
        LayoutManager.shared.save(layout, for: gameId)
    }

    var body: some View  {
        VStack {
            HStack {
                Button("Hide") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showEditControls = false
                    }
                }
                .foregroundColor(.red)
                
                Button("Layout Options") {
                    showingLayoutOptions = true
                }
                .foregroundColor(.blue)
                
                Spacer()
                
                Button("Reset Current") {
                    layout = LayoutConfig()
                    LayoutManager.shared.reset(for: gameId)
                    selectedButton = nil
                    selectedJoystick = nil
                }
                .foregroundColor(.red)
                
                Spacer()
                
                if let selectedButton = selectedButton {
                    Button("Reset Selected") {
                        layout.buttons[selectedButton] = nil
                        self.selectedButton = nil
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal)
                } else if let selectedJoystick = selectedJoystick {
                    Button("Reset Selected") {
                        layout.joysticks[selectedJoystick] = nil
                        self.selectedJoystick = nil
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal)
                }
                
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        saveLayout()
                        selectedButton = nil
                        selectedJoystick = nil
                    }
                    isEditing.toggle()
                }
                .padding(.horizontal)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            
            // Game indicator
            if let gameId = gameId {
                HStack {
                    Image(systemName: "gamecontroller.fill")
                        .foregroundColor(.blue)
                        .padding(.vertical)
                    Text("Game: \(gameId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical)
                    if LayoutManager.shared.hasCustomLayout(for: gameId) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
            }
            
            if let selectedButton = selectedButton {
                buttonScaleControls(for: selectedButton)
            } else if let selectedJoystick = selectedJoystick {
                joystickScaleControls(for: selectedJoystick)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            loadLayout()
        }
        .onChange(of: gameId) { _ in
            loadLayout()
        }
        .sheet(isPresented: $showingLayoutOptions) {
            LayoutOptionsView(gameId: gameId, layout: $layout)
        }
    }
    
    private func buttonScaleControls(for buttonId: String) -> some View {
        VStack {
            Text("Button Scale: \(String(format: "%.1f", layout.buttons[buttonId]?.scale ?? 1.0))")
                .font(.headline)
            
            HStack {
                Button("-") {
                    let currentScale = layout.buttons[buttonId]?.scale ?? 1.0
                    layout.buttons[buttonId, default: ButtonLayout()].scale = max(0.5, currentScale - 0.1)
                }
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Slider(
                    value: Binding(
                        get: { layout.buttons[buttonId]?.scale ?? 1.0 },
                        set: { layout.buttons[buttonId, default: ButtonLayout()].scale = $0 }
                    ),
                    in: 0.5...2.0,
                    step: 0.1
                )
                
                Button("+") {
                    let currentScale = layout.buttons[buttonId]?.scale ?? 1.0
                    layout.buttons[buttonId, default: ButtonLayout()].scale = min(2.0, currentScale + 0.1)
                }
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            Toggle(isOn: Binding(get: { layout.buttons[buttonId]?.hidden ?? false }, set: { layout.buttons[buttonId, default: ButtonLayout()].hidden = $0 })) {
                Text("Hide Button")
            }
            .accentColor(.blue)
            
            Toggle(isOn: Binding(get: { layout.buttons[buttonId]?.toggle ?? false }, set: { layout.buttons[buttonId, default: ButtonLayout()].toggle = $0 })) {
                Text("Make Button Toggle")
            }
            .accentColor(.blue)
            
            if buttonId.lowercased().contains("dpad") {
                Toggle(isOn: Binding(get: { joystickDpad.joystickDpad }, set: { joystickDpad.joystickDpad = $0 })) {
                    Text("Make D-Pad act like Joystick")
                }
                .accentColor(.blue)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private func joystickScaleControls(for joystickId: String) -> some View {
        VStack {
            Text("Joystick Scale: \(String(format: "%.1f", layout.joysticks[joystickId]?.scale ?? 1.0))")
                .font(.headline)
            
            HStack {
                Button("-") {
                    let currentScale = layout.joysticks[joystickId]?.scale ?? 1.0
                    layout.joysticks[joystickId, default: JoystickLayout()].scale = max(0.5, currentScale - 0.1)
                }
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Slider(
                    value: Binding(
                        get: { layout.joysticks[joystickId]?.scale ?? 1.0 },
                        set: { layout.joysticks[joystickId, default: JoystickLayout()].scale = $0 }
                    ),
                    in: 0.5...2.0,
                    step: 0.1
                )
                
                Button("+") {
                    let currentScale = layout.joysticks[joystickId]?.scale ?? 1.0
                    layout.joysticks[joystickId, default: JoystickLayout()].scale = min(2.0, currentScale + 0.1)
                }
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            Toggle(isOn: Binding(get: { layout.joysticks[joystickId]?.hidden ?? false }, set: { layout.joysticks[joystickId, default: JoystickLayout()].hide = $0 })) {
                Text("Hide Joystick")
            }
            .accentColor(.green)
            
            Toggle(isOn: Binding(get: { layout.joysticks[joystickId]?.hide ?? true }, set: { layout.joysticks[joystickId, default: JoystickLayout()].hide = $0 })) {
                Text("Hide ABXY / Arrow Buttons")
            }
            .accentColor(.green)
            
            Toggle(isOn: Binding(get: { layout.joysticks[joystickId]?.background ?? false }, set: { layout.joysticks[joystickId, default: JoystickLayout()].background = $0 })) {
                Text("Always show Joystick Background")
            }
            .accentColor(.green)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

}
