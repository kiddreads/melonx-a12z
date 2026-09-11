//
//  GameInfo.swift
//  MeloNX
//
//  Created by Stossy11 on 9/12/2024.
//

import SwiftUI
import UniformTypeIdentifiers

public struct Game: Codable, Identifiable, Equatable, Hashable, Sendable {
    public var id: URL { fileURL }

    var containerFolder: URL
    var fileType: UTType
    var fileURL: URL

    var titleName: String
    var titleId: String
    var developer: String
    var version: String
    var iconData: Data?
    var icon: UIImage? {
        UIImage(data: iconData ?? Data())
    }
    
    
    static func convertGameInfoToGame(gameInfo: GameInfo, url: URL) -> Game {
        var gameTemp = Game(containerFolder: url.deletingLastPathComponent(), fileType: .item, fileURL: url, titleName: "", titleId: "", developer: "", version: "")
    
        setName(gameInfo, game: &gameTemp)
        gameTemp.iconData = createImage(from: gameInfo)
        
        SN_free_game_info(gameInfo)
        
        return gameTemp
    }
    
    static func setName(_ gameInfo: GameInfo, game gameTemp: inout Game) {
        gameTemp.titleName = withUnsafePointer(to: gameInfo.TitleName) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout.size(ofValue: $0)) {
                String(cString: $0)
            }
        }
        
        gameTemp.developer = withUnsafePointer(to: gameInfo.Developer) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout.size(ofValue: $0)) {
                String(cString: $0)
            }
        }
        
        gameTemp.titleId = withUnsafePointer(to: gameInfo.TitleId) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout.size(ofValue: $0)) {
                String(cString: $0)
            }
        }
        
        
        gameTemp.version = withUnsafePointer(to: gameInfo.Version) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout.size(ofValue: $0)) {
                String(cString: $0)
            }
        }
    }
    
   static func createImage(from gameInfo: GameInfo) -> Data? {
       let imageSize = Int(gameInfo.ImageSize)
       if imageSize > 0, imageSize <= 1024 * 1024 {
           return Data(bytes: gameInfo.ImageData, count: imageSize)
       }
       return nil
    }
}
