//
//  GameScheme.swift
//  MeloNX
//
//  Created by Stossy11 on 14/12/2025.
//

import Foundation

struct GameScheme: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id = UUID().uuidString
    
    var titleName: String
    var titleId: String
    var developer: String
    var version: String
    var iconData: Data?
    
    static func pullFromURL(_ url: URL, otherURL: @escaping () -> Void) -> [GameScheme] {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            if components.host == "melonx" {
                if let text = components.queryItems?.first(where: { $0.name == "games" })?.value, let data = GameScheme.base64URLDecode(text) {
                    
                    if let decoded = try? JSONDecoder().decode([GameScheme].self, from: data) {
                        return decoded
                    }
                }
            }
        }
        
        otherURL()
        return []
    }
    
    private static func base64URLDecode(_ text: String) -> Data? {
        var base64 = text
        base64 = base64.replacingOccurrences(of: "-", with: "+")
        base64 = base64.replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64 = base64.appending("=")
        }
        return Data(base64Encoded: base64)
    }
}
