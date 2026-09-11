//
//  MeloMTKView.swift
//  MeloNX
//
//  Created by Stossy11 on 03/03/2025.
//

import MetalKit
import UIKit

class MeloMTKView: MTKView {
    private var activeTouches: [UITouch] = []
    private var ignoredTouches: Set<UITouch> = []

    private var aspectRatio: AspectRatio = .fixed16x9

    func setAspectRatio(_ ratio: AspectRatio) {
        self.aspectRatio = ratio
        RyujinxBridge.setViewSize(width: Int(self.bounds.width), height: Int(self.bounds.height))
    }
    
    private func transformToTargetCoordinates(_ point: CGPoint) -> CGPoint {
        return point
    }

    private func getNextAvailableIndex() -> Int {
        return activeTouches.endIndex
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        let disabled = UserDefaults.standard.bool(forKey: "disableTouch")
        guard !disabled else { return }
        
        setAspectRatio(Ryujinx.shared.aspectRatio)
        
        for touch in touches {
            let location = touch.location(in: self)
            let index = getNextAvailableIndex()
            activeTouches.append(touch)
            print("Touch location: \(location)")
            let transformed = transformToTargetCoordinates(location)
            RyujinxBridge.touchBegan(x: Float(transformed.x), y: Float(transformed.y), index: index)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        
        let disabled = UserDefaults.standard.bool(forKey: "disableTouch")
        guard !disabled else {
            for touch in touches {
                ignoredTouches.remove(touch)
                if let index = activeTouches.firstIndex(of: touch) {
                    activeTouches.remove(at: index)
                }
            }
            return
        }
        
        for touch in touches {
            if ignoredTouches.remove(touch) != nil {
                continue
            }
            
            if let touchIndex = activeTouches.firstIndex(where: { $0 == touch }) {
                RyujinxBridge.touchEnded(index: touchIndex)
                
                if let arrayIndex = activeTouches.firstIndex(of: touch) {
                    activeTouches.remove(at: arrayIndex)
                }
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        
        let disabled = UserDefaults.standard.bool(forKey: "disableTouch")
        guard !disabled else { return }
        
        setAspectRatio(Ryujinx.shared.aspectRatio)
        
        for touch in touches {
            if ignoredTouches.contains(touch), !activeTouches.contains(touch) {
                continue
            }
            
            
            guard let touchIndex = activeTouches.firstIndex(where: { $0 == touch }) else {
                continue
            }
            
            let location = touch.location(in: self)
            let transformed = transformToTargetCoordinates(location)
            RyujinxBridge.touchMoved(x: Float(transformed.x), y: Float(transformed.y), index: touchIndex)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        let disabled = UserDefaults.standard.bool(forKey: "disableTouch")
        guard !disabled else {
            for touch in touches {
                ignoredTouches.remove(touch)
                if let index = activeTouches.firstIndex(of: touch) {
                    activeTouches.remove(at: index)
                }
            }
            return
        }
        
        for touch in touches {
            if ignoredTouches.remove(touch) != nil {
                continue
            }
            
            if let touchIndex = activeTouches.firstIndex(where: { $0 == touch }) {
                RyujinxBridge.touchEnded(index: touchIndex)
                activeTouches.remove(at: touchIndex)
            }
        }
    }
    

    func resetTouchTracking() {
        activeTouches.removeAll()
        ignoredTouches.removeAll()
    }
}

