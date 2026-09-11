//
//  ControllerLayout.swift
//  MeloNX
//
//  Created by Stossy11 on 04/12/2025.
//

import Foundation

struct ButtonLayout: Codable, Equatable {
    var offset: CGSize = .zero
    var scale: CGFloat = 1.0
    var hidden: Bool = false
    var toggle: Bool = false
    var dpadToJoystickl: Bool = false
}

struct JoystickLayout: Codable, Equatable {
    var offset: CGSize = .zero
    var scale: CGFloat = 1.0
    var hide: Bool = true
    var background: Bool = false
    var hidden: Bool = false
}

struct LayoutConfig: Codable, Equatable {
    var buttons: [String: ButtonLayout] = [:]
    var joysticks: [String: JoystickLayout] = [:]
}

