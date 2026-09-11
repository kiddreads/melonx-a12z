//
//  ControllerRow.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import SwiftUI

struct ControllerRow: View {
    let index: Int
    let controllerId: String
    @ObservedObject var controllerManager: ControllerManager
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .foregroundColor(.blue)
                
                Text("Player \(index + 1): \(controller.name)")
                    .lineLimit(1)
                
                Spacer()
                
                Button {
                    controllerManager.toggleController(controller)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            
            if index < controllerManager.selectedControllers.count - 1 {
                Divider()
            }
        }
        .contextMenu {
            ForEach(ControllerType.allCases) { type in
                if controllerManager.allControllers[controllerIndex].type == type {
                    Button {
                        updateControllerType(to: type)
                    } label: {
                        Label(type.rawValue, systemImage: "checkmark")
                    }
                } else {
                    Button(type.rawValue) {
                        updateControllerType(to: type)
                    }
                    .tag(type)
                }
            }
        }
    }
    
    private var controller: BaseController {
        controllerManager.controllerAndIndexForString(controllerId)!.0
    }
    
    private var controllerIndex: Int {
        controllerManager.controllerAndIndexForString(controllerId)!.1
    }
    
    private func updateControllerType(to type: ControllerType) {
        controllerManager.allControllers[controllerIndex].type = type
        controllerManager.controllerTypes[index] = type
    }
}
