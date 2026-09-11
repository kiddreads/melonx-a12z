//
//  ProcessInfo.swift
//  MeloNX
//
//  Created by Stossy11 on 27/2/2026.
//

import Foundation

extension ProcessInfo {
    var isiOSAppOnMac: Bool {
        URL.documentsDirectory.path.hasPrefix("/Users/")
    }
}
