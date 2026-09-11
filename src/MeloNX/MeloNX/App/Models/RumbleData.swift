//
//  RumbleData.swift
//  MeloNX
//
//  Created by Stossy11 on 14/11/2025.
//


struct RumbleData {
    var lowFrequency: Float
    var highFrequency: Float
    var durationMs: UInt32
    
    init?(data: Data) {
        guard data.count == MemoryLayout<RumbleData>.size else { return nil }

        self = data.withUnsafeBytes { rawBuffer in
            rawBuffer.load(as: RumbleData.self)
        }
    }
}
