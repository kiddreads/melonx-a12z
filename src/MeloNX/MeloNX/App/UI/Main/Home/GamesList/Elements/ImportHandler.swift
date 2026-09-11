//
//  ImportHandler.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import Foundation

class ImportHandler {
    static public func handleRunningGame(result: Result<[URL], Error>, gameHandler: LaunchGameHandler) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                return
            }
            
            _ = url.startAccessingSecurityScopedResource()
            
            do {
                let handle = try FileHandle(forReadingFrom: url)
                let fileExtension = (url.pathExtension as NSString)
                
                let gameInfo = RyujinxBridge.getGameInfo(arg0: handle.fileDescriptor, arg1: fileExtension)
                
                let game = Game.convertGameInfoToGame(gameInfo: gameInfo, url: url)
                
                Task { @MainActor in
                    gameHandler.currentGame = game
                }
            } catch {
            }
            
        case .failure(let err):
            print("File import failed: \(err.localizedDescription)")
        }
    }
    
    static public func handleAddingGame(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                return
            }
            
            let cool = url.startAccessingSecurityScopedResource()
            defer { cool ? url.stopAccessingSecurityScopedResource() : () }
            
            do {
                if !GameFileType.isSupported(fileExtension: url.pathExtension) {
                    showAlert(title: "Failed to import", message: "Unsupported file extension", actions:
                        [
                            (title: "Cancel", style: .cancel, handler: nil)
                        ]
                    )
                }
                
                let fileManager = FileManager.default
                let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                let romsDirectory = documentsDirectory.appendingPathComponent("roms")
                
                if !fileManager.fileExists(atPath: romsDirectory.path) {
                    try? fileManager.createDirectory(at: romsDirectory, withIntermediateDirectories: true, attributes: nil)
                }
                
                let destinationURL = romsDirectory.appendingPathComponent(url.lastPathComponent)
                try fileManager.copyItem(at: url, to: destinationURL)
                
                Ryujinx.shared.games = Ryujinx.shared.loadGames()
            } catch {
                showAlert(title: "Failed to import", message: error.localizedDescription, actions:
                    [
                        (title: "Cancel", style: .cancel, handler: nil)
                    ]
                )
            }
        case .failure(let err):
            print("File import failed: \(err.localizedDescription)")
        }
    }
    
    static public func handleFirmwareImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let url):
            guard let url = url.first else {
                return
            }
            
            do {
                let fun = url.startAccessingSecurityScopedResource()
                let path = url.path
                    
                let (string, isErr) = RyujinxBridge.installFirmware(at: path)
                
                if isErr {
                    showAlert(title: "Installing Firmware Failed", message: string, actions:
                                [
                                    (title: "Cancel", style: .cancel, handler: nil)
                                ]
                    )
                } else {
                    Ryujinx.shared.firmwareversion = string
                }
                
                if fun {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        case .failure(let error):
            showAlert(title: "Installing Firmware Failed", message: error.localizedDescription, actions:
                        [
                            (title: "Cancel", style: .cancel, handler: nil)
                        ]
            )
        }
    }
    
}
