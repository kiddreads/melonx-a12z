//
//  LayoutManager.swift
//  MeloNX
//
//  Created by Stossy11 on 04/12/2025.
//

import Foundation

class LayoutManager {
    static let shared = LayoutManager()
    private init() {}

    private var baseURL: URL {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docDir.appendingPathComponent("controller_layouts")
    }
    
    private func fileURL(for gameId: String?) -> URL {
        let fileName = gameId?.isEmpty == false ? "\(gameId!).json" : "default.json"
        return baseURL.appendingPathComponent(fileName)
    }
    
    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    func save(_ layout: LayoutConfig, for gameId: String? = nil) {
        ensureDirectoryExists()
        try? JSONEncoder().encode(layout).write(to: fileURL(for: gameId))
    }

    func load(for gameId: String? = nil) -> LayoutConfig {
        let url = fileURL(for: gameId)
        guard let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(LayoutConfig.self, from: data) else {
            // If no game-specific layout exists, try to load default
            if gameId != nil {
                return load(for: nil)
            }
            return LayoutConfig()
        }
        return config
    }

    // Legacy support for old layout format
    func loadLegacy(for gameId: String? = nil) -> [String: ButtonLayout] {
        let url = fileURL(for: gameId)
        guard let data = try? Data(contentsOf: url),
              let legacyConfig = try? JSONDecoder().decode([String: ButtonLayout].self, from: data) else {
            return [:]
        }
        return legacyConfig
    }

    func reset(for gameId: String? = nil) {
        let url = fileURL(for: gameId)
        try? FileManager.default.removeItem(at: url)
    }
    
    func resetAll() {
        try? FileManager.default.removeItem(at: baseURL)
    }
    
    func hasCustomLayout(for gameId: String) -> Bool {
        let url = fileURL(for: gameId)
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    func copyLayout(from sourceGameId: String?, to targetGameId: String?) {
        let sourceLayout = load(for: sourceGameId)
        save(sourceLayout, for: targetGameId)
    }
    
    func getAllGameLayouts() -> [String] {
        ensureDirectoryExists()
        guard let files = try? FileManager.default.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.compactMap { url in
            let filename = url.lastPathComponent
            guard filename.hasSuffix(".json") && filename != "default.json" else { return nil }
            return String(filename.dropLast(5)) // Remove .json extension
        }
    }
}

extension VirtualControllerButton: Identifiable {
    public var id: String { "\(self)" }
}
