//
//  JoystickViewRepresentable.swift
//  MeloNX
//
//  Created by Stossy11 on 28/2/2026.
//


import SwiftUI

struct JoystickViewRepresentable: UIViewRepresentable {
    
    var right: Bool
    var showBackground: Bool
    @Binding var position: CGPoint
    var mPosition: Bool = true
    
    init(right: Bool, showBackground: Bool = false, position: Binding<CGPoint>) {
        self.right = right
        self._position = position
        self.showBackground = showBackground
    }
    
    init(right: Bool, showBackground: Bool = false) {
        self.right = right
        self._position = .constant(.zero)
        self.showBackground = showBackground
        mPosition = false
    }
    
    func makeUIView(context: Context) -> JoystickView {
        let view = JoystickView()
        view.right = right
        view.background = showBackground
        
        if mPosition {
            view.onPositionChanged = { newPosition in
                DispatchQueue.main.async {
                    self.position = newPosition
                }
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: JoystickView, context: Context) {}
}
