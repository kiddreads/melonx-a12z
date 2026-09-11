//
//  ButtonView.swift
//  MeloNX
//
//  Created by Stossy11 on 26/1/2026.
//

import SwiftUI

struct ButtonView: View {
    var disabled: Bool
    var button: VirtualControllerButton
    var opacity: Double
    @Binding var layout: LayoutConfig?
    var joystickDpadPoint: JoystickDPadPoint = .shared
    
    @AppStorage("onscreenhandheld") var onscreenjoy: Bool = false
    @AppStorage("joystickDpad") private var joystickDpad = false
    @AppStorage("On-ScreenControllerScale") var controllerScale: Double = 1.0
    @Environment(\.presentationMode) var presentationMode
    
    @State private var istoggle = false
    @State private var isPressed = false
    @State private var toggleState = false
    @State private var size: CGSize = .zero
    
    init(disabled: Bool = false, button: VirtualControllerButton, opacity: Double = 1.0, layout: Binding<LayoutConfig> = .constant(LayoutConfig())) {
        self.disabled = disabled
        self.button = button
        self.opacity = opacity
        if layout.wrappedValue == LayoutConfig() {
            _layout = .constant(nil)
        } else {
            _layout = Binding(
                get: { layout.wrappedValue },
                set: { layout.wrappedValue = $0 ?? LayoutConfig() }
            )
        }
    }
    
    var body: some View {
        Circle()
            .foregroundStyle(.clear.opacity(0))
            .overlay {
                Image(systemName: buttonConfig.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width, height: size.height)
                    .foregroundStyle(.white)
                    .opacity(isPressed ? 0.6 : 0.8)
                    .allowsHitTesting(false)
            }
            .frame(width: size.width, height: size.height)
            .background(buttonBackground)
            .onAppear {
                if layout != nil {
                    istoggle = layout?.buttons[button.id]?.toggle ?? false
                }
                size = calculateButtonSize()
            }
            .onChange(of: controllerScale) { _ in
                size = calculateButtonSize()
            }
            .overlay {
                if !disabled {
                    ControllerUIButtonViewRepresentable(onPress: handleButtonPress, onRelease: handleButtonRelease)
                        .allowsHitTesting(true)
                        .frame(width: size.width * 1.25, height: size.height * 1.25)
                }
            }
            .opacity(opacity)
    }
    
    private var buttonBackground: some View {
        Group {
            if !button.isTrigger && button != .leftStick && button != .rightStick {
                Circle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: size.width * 1.25, height: size.height * 1.25)
            } else if button == .leftStick || button == .rightStick {
                Image(systemName: buttonConfig.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width * 1.25, height: size.height * 1.25)
                    .foregroundColor(Color.gray.opacity(0.4))
            } else if button.isTrigger {
                Image(systemName: convertTriggerIconToButton(buttonConfig.iconName))
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width * 1.25, height: size.height * 1.25)
                    .foregroundColor(Color.gray.opacity(0.4))
            }
        }
    }
    
    private func convertTriggerIconToButton(_ iconName: String) -> String {
        if iconName.hasPrefix("zl") || iconName.hasPrefix("zr") {
            var converted = String(iconName.dropFirst(3))
            converted = converted.replacingOccurrences(of: "rectangle", with: "button")
            converted = converted.replacingOccurrences(of: ".fill", with: ".horizontal.fill")
            return converted
        } else {
            var converted = String(iconName.dropFirst(2))
            converted = converted.replacingOccurrences(of: "rectangle", with: "button")
            converted = converted.replacingOccurrences(of: ".fill", with: ".horizontal.fill")
            return converted
        }
    }
    
    let virtualController = ControllerManager.shared.virtualController
    
    private func handleButtonPress() {
        DispatchQueue.global(qos: .userInteractive).async {
            guard !isPressed || istoggle else { return }
            
            if istoggle {
                toggleState.toggle()
                isPressed = toggleState
                if joystickDpad, button.isDPad {
                    if toggleState {
                        joystickDpadPoint.pressed(button)
                    } else {
                        joystickDpadPoint.released(button)
                    }
                } else {
                    let value = toggleState ? 1 : 0
                    virtualController.setButtonState(Uint8(value), for: button)
                }
                Haptics.shared.play(.soft)
            } else {
                isPressed = true
                if joystickDpad, button.isDPad {
                    joystickDpadPoint.pressed(button)
                } else {
                    virtualController.setButtonState(1, for: button)
                }
                Haptics.shared.play(.soft)
            }
        }
    }
    
    private func handleButtonRelease() {
        if istoggle { return }
        guard isPressed else { return }

        isPressed = false
        DispatchQueue.global(qos: .userInteractive).async {
            if joystickDpad, button.isDPad {
                joystickDpadPoint.released(button); return
            }
            virtualController.setButtonState(0, for: button)
        }
    }
    
    private func calculateButtonSize() -> CGSize {
        let baseWidth: CGFloat
        let baseHeight: CGFloat
        
        if button.isTrigger {
            baseWidth = 70
            baseHeight = 40
        } else if button.isSmall {
            baseWidth = 35
            baseHeight = 35
        } else {
            baseWidth = 45
            baseHeight = 45
        }
        
        let deviceMultiplier = UIDevice.current.userInterfaceIdiom == .pad ? 1.2 : 1.0
        let scaleMultiplier = CGFloat(controllerScale)
        
        return CGSize(
            width: baseWidth * deviceMultiplier * scaleMultiplier,
            height: baseHeight * deviceMultiplier * scaleMultiplier
        )
    }
    
    private var buttonConfig: ButtonConfiguration {
        ButtonConfiguration.config(for: button)
    }
}
