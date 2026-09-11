//
//  SettingsManager.swift
//  MeloNX
//
//  Created by Stossy11 on 07/11/2025.
//

import Foundation

class SettingsManager: ObservableObject {
    @Published var config: Ryujinx.Arguments {
        didSet {
            debouncedSave()
        }
    }
    
    private var saveWorkItem: DispatchWorkItem?;
    
    public static var shared = SettingsManager()
    
    private init() {
        self.config = SettingsManager.loadSettings() ?? Ryujinx.Arguments()
    }
    
    func debouncedSave() {
        saveWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.saveSettings()
        }
        
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    
    func saveSettings() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            
            let fileURL = URL.documentsDirectory.appendingPathComponent("config.json")
            
            try data.write(to: fileURL)
            print("Settings saved successfully")
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
    
    static func loadSettings() -> Ryujinx.Arguments? {
        do {
            let fileURL = URL.documentsDirectory.appendingPathComponent("config.json")
            
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("Config file does not exist, creating new config")
                return nil
            }
            
            let data = try Data(contentsOf: fileURL)
            
            let decoder = JSONDecoder()
            let configs = try decoder.decode(Ryujinx.Arguments.self, from: data)
            return configs
        } catch {
            print("Failed to load settings: \(error)")
            return nil
        }
    }
    
    func loadSettings() {
        do {
            let fileURL = URL.documentsDirectory.appendingPathComponent("config.json")
            
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("Config file does not exist, creating new config")
                saveSettings()
                return
            }
            
            let data = try Data(contentsOf: fileURL)
            
            let decoder = JSONDecoder()
            let configs = try decoder.decode(Ryujinx.Arguments.self, from: data)
            
            self.config = configs
        } catch {
            print("Failed to load settings: \(error)")
        }
    }
}
