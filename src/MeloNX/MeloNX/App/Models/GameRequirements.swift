//
//  GameRequirements.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import Foundation
import SwiftUI

struct GameRequirements: Codable {
    var game_id: String
    var compatibility: String
    var device_memory: String
    var memoryInt: Int {
        var devicemem = device_memory
        devicemem.removeLast(2)
        // print(devicemem)
        return Int(devicemem) ?? 0
    }
    
    var color: Color {
        switch compatibility {
        case "Perfect":
            return .green
        case "Playable":
            return .yellow
        case "Menu":
            return .orange
        case "Boots":
            return .red
        case "Nothing":
            return .black
        default:
            return .clear
        }
    }
}
