//
//  MetalView.swift
//  MeloNX
//
//  Created by Stossy11 on 09/02/2025.
//

import SwiftUI
import MetalKit
import Metal

struct MetalView: UIViewRepresentable {
    var airplay: Bool = Air.shared.connected // just in case :3
    
    func makeUIView(context: Context) -> UIView {
        return Self.createView()
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // nothin
    }
    
    @discardableResult
    static func createView() -> UIView {
        if Ryujinx.shared.emulationUIView == nil {
            let view = MeloMTKView()
            
            guard let metalLayer = view.layer as? CAMetalLayer else {
                fatalError("[Swift] Error: MTKView's layer is not a CAMetalLayer")
            }
            
            UIApplication.shared.isIdleTimerDisabled = true
            
            //metalLayer.presentsWithTransaction = false
            //metalLayer.allowsNextDrawableTimeout = false
            
            
            let framesSelector = NSSelectorFromString("setNominalFramesPerSecond:")
            
            if metalLayer.responds(to: framesSelector) {
                metalLayer.perform(framesSelector, with: 60 as NSNumber)
            }
            
            let setterSelector = NSSelectorFromString("setDisplaySyncEnabled:")
            
            if metalLayer.responds(to: setterSelector) {
                metalLayer.perform(setterSelector, with: NSNumber(value: false))
            }
            
            notnil(metalLayer.device) ? () : (metalLayer.device = MTLCreateSystemDefaultDevice())
            
            let layerPtr = Unmanaged.passUnretained(metalLayer).toOpaque()
            
            RyujinxBridge.setNativeWindow(layerPtr)
            
            Ryujinx.shared.emulationUIView = view
            Ryujinx.shared.metalLayer = metalLayer
            return view
        }
        
        return Ryujinx.shared.emulationUIView!
    }
}
