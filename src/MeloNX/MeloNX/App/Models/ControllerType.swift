//
//  ControllerType.swift
//  MeloNX
//
//  Created by Stossy11 on 24/07/2025.
//

import Foundation

// Commented ones our are privated ones and will not be shown in the UI.
enum ControllerType: String, CaseIterable, Identifiable, Hashable, Codable {
    // case none = "None"
    case proController = "ProController"
    case handheld = "Handheld"
    case joyconPair = "JoyconPair"
    case joyconLeft = "JoyconLeft"
    case joyconRight = "JoyconRight"
    // case invalid = "Invalid"
    // case pokeball = "Pokeball"
    // case systemExternal = "SystemExternal"
    // case system = "System"
    var id: String { self.rawValue }
}
