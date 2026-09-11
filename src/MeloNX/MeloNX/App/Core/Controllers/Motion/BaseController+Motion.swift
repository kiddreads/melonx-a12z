//
//  BaseController+Motion.swift
//  MeloNX
//
//  Created by Stossy11 on 16/11/2025.
//

import Foundation
import CoreMotion

private var debugCounter = 0

extension BaseController {
    func setupMotion() {
        if let nativeController, nativeController.motion != nil, !self.usesDeviceHandlers {
            nativeController.motion?.sensorsActive = true
            
            // Thank you @BXYMartin :3
            nativeController.motion?.valueChangedHandler = { [weak self] m in
                guard let self = self else { return }
                let rawAccelX = Float(m.acceleration.x)
                let rawAccelY = Float(m.acceleration.y)
                let rawAccelZ = Float(m.acceleration.z)

                let rawGyroDeg = SIMD3<Float>(
                    Float(m.rotationRate.x),
                    Float(m.rotationRate.y),
                    Float(m.rotationRate.z)
                ) * 180.0 / .pi

                let accel = SIMD3(-rawAccelX, -rawAccelZ, rawAccelY)
                let gyro = SIMD3(rawGyroDeg.x, rawGyroDeg.z, -rawGyroDeg.y)

                self.motionQueue.async {
                    RyujinxBridge.setGamepadMotion(self.pointer, motionType: 1, axis: accel)
                    RyujinxBridge.setGamepadMotion(self.pointer, motionType: 2, axis: gyro)
                }
            }
        } else {
            guard self.motionManager.isDeviceMotionAvailable else { return }
            
            self.motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60Hz
            self.motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
                guard let self = self, let m = data else { return }
                
                
                let rawAccel = SIMD3<Float>(
                    -Float(m.gravity.x + m.userAcceleration.x),
                    -Float(m.gravity.y + m.userAcceleration.y),
                    -Float(m.gravity.z + m.userAcceleration.z)
                )
                
                let rawGyro = SIMD3<Float>(
                    Float(m.rotationRate.x),
                    -Float(m.rotationRate.y),
                    -Float(m.rotationRate.z)
                ) * (180.0 / .pi)
                
                self.motionQueue.async {
                    let (mappedAccel, mappedGyro) = self.remapToSwitchCoords(accel: rawAccel, gyro: rawGyro)
                    
                    RyujinxBridge.setGamepadMotion(self.pointer, motionType: 1, axis: mappedAccel)
                    RyujinxBridge.setGamepadMotion(self.pointer, motionType: 2, axis: mappedGyro)
                }
            }
        }
    }
    
    private func remapToSwitchCoords(accel: SIMD3<Float>, gyro: SIMD3<Float>) -> (SIMD3<Float>, SIMD3<Float>) {
        let orientation = UIDevice.current.orientation
        
        var finalAccel: SIMD3<Float>
        var finalGyro: SIMD3<Float>
        
        switch orientation {
        case .landscapeLeft:
            finalAccel = SIMD3<Float>(accel.y, -accel.x, accel.z)
            finalGyro = SIMD3<Float>(gyro.y, -gyro.x, gyro.z)
        case .landscapeRight:
            finalAccel = SIMD3<Float>(-accel.y, accel.x, accel.z)
            finalGyro = SIMD3<Float>(-gyro.y, gyro.x, gyro.z)
        default: // Portrait
            finalAccel = SIMD3<Float>(accel.x, accel.z, -accel.y)
            finalGyro = SIMD3<Float>(gyro.x, gyro.z, -gyro.y)
        }
        
        return (finalAccel, finalGyro)
    }
}
