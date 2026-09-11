//
//  ButtonConfiguration.swift
//  MeloNX
//
//  Created by Stossy11 on 26/1/2026.
//

import SwiftUI

struct ButtonConfiguration {
    let iconName: String
    
    static func config(for button: VirtualControllerButton) -> ButtonConfiguration {
        switch button {
        case .A: return ButtonConfiguration(iconName: "a.circle.fill")
        case .B: return ButtonConfiguration(iconName: "b.circle.fill")
        case .X: return ButtonConfiguration(iconName: "x.circle.fill")
        case .Y: return ButtonConfiguration(iconName: "y.circle.fill")
        case .leftStick: return ButtonConfiguration(iconName: "l.joystick.press.down.fill")
        case .rightStick: return ButtonConfiguration(iconName: "r.joystick.press.down.fill")
        case .dPadUp: return ButtonConfiguration(iconName: "arrowtriangle.up.circle.fill")
        case .dPadDown: return ButtonConfiguration(iconName: "arrowtriangle.down.circle.fill")
        case .dPadLeft: return ButtonConfiguration(iconName: "arrowtriangle.left.circle.fill")
        case .dPadRight: return ButtonConfiguration(iconName: "arrowtriangle.right.circle.fill")
        case .leftTrigger: return ButtonConfiguration(iconName: "zl.rectangle.roundedtop.fill")
        case .rightTrigger: return ButtonConfiguration(iconName: "zr.rectangle.roundedtop.fill")
        case .leftShoulder: return ButtonConfiguration(iconName: "l.rectangle.roundedbottom.fill")
        case .rightShoulder: return ButtonConfiguration(iconName: "r.rectangle.roundedbottom.fill")
        case .start: return ButtonConfiguration(iconName: "plus.circle.fill")
        case .back: return ButtonConfiguration(iconName: "minus.circle.fill")
        case .guide: return ButtonConfiguration(iconName: "gearshape.fill")
        }
    }
}
