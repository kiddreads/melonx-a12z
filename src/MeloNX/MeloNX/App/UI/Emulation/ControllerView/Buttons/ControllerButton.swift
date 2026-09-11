//
//  ControllerButton.swift
//  MeloNX
//
//  Created by Stossy11 on 10/1/2026.
//

import UIKit
import SwiftUI

class ControllerUIButton: UIButton {
    
    private var isPressing = false
    
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = true
        self.isMultipleTouchEnabled = false
        
        self.addTarget(self, action: #selector(handleTap), for: .touchDown)
        self.addTarget(self, action: #selector(handleRelease), for: .touchUpInside)
    }
    
    @objc private func handleTap(_ sender: UIButton) {
        press()
    }
    
    @objc private func handleRelease(_ sender: UIButton) {
        release()
    }
    
    func press() {
        if !isPressing {
            isPressing = true
            onPress?()
        }
    }
    
    func release() {
        if isPressing {
            isPressing = false
            onRelease?()
        }
    }
}

struct ControllerUIButtonViewRepresentable: UIViewRepresentable {
    let onPress: () -> Void
    let onRelease: () -> Void
    
    func makeUIView(context: Context) -> ControllerUIButton {
        let button = ControllerUIButton(frame: .zero)
        button.onPress = onPress
        button.onRelease = onRelease
        return button
    }
    
    func updateUIView(_ uiView: ControllerUIButton, context: Context) {
        uiView.onPress = onPress
        uiView.onRelease = onRelease
    }
}

