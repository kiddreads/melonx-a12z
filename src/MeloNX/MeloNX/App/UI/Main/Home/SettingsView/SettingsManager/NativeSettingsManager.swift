//
//  NativeSettingsManager.swift
//  MeloNX
//
//  Created by Stossy11 on 07/11/2025.
//

import Foundation
import SwiftUI
import Combine

@dynamicMemberLookup
class NativeSettingsManager: ObservableObject {
    var settings: Set<AnyHashable> = []
    static var shared = NativeSettingsManager()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in self?.objectWillChange.send() }
            }
            .store(in: &cancellables)
    }
    
    subscript<T: Any>(dynamicMember member: String) -> (T) -> Setting<T> {
        return { [weak self] input in
            Setting<T>.getOrCreateSetting(named: member, default: input, self: self)
        }
    }
    
    subscript<T: Any>(dynamicMember member: String) -> Setting<T> {
        if T.self == Bool.self {
            return Setting<T>.getOrCreateSetting(named: member, default: false as? T, self: self)
        } else if T.self == Double.self {
            return Setting<T>.getOrCreateSetting(named: member, default: 0 as? T, self: self)
        }
        
        return Setting<T>.getOrCreateSetting(named: member, default: nil, self: self)
    }
    
    func setting<T: Any>(forKey key: String, default defaultValue: T) -> Setting<T> {
        Setting<T>.getOrCreateSetting(named: key, default: defaultValue, self: self)
    }
}

class Setting<T: Any>: Hashable {
    static func == (lhs: Setting<T>, rhs: Setting<T>) -> Bool {
        lhs.name == rhs.name && lhs.parent === rhs.parent
    }
    
    var name: String
    var uddefault: Any
    weak var parent: NativeSettingsManager?
    
    func hash(into hasher: inout Hasher) {
        if let parent {
            hasher.combine(ObjectIdentifier(parent))
        }
        hasher.combine(name)
        hasher.combine(ObjectIdentifier(Mirror(reflecting: uddefault).subjectType))
    }
    
    var projectedValue: Binding<T> {
        Binding(get: { self.value }, set: { self.value = $0 })
    }
    
    init(name: String, defaultAny: T?, parent: NativeSettingsManager? = nil) {
        self.name = name
        self.uddefault = defaultAny ?? UUID()
        self.parent = parent
        
        if UserDefaults.standard.object(forKey: name) == nil {
            self.setInitialValue(defaultAny)
        }
    }
    
    private func setInitialValue(_ value: T?) {
        guard let value = value else { return }
        
        if isPropertyListCompatible(value) {
            UserDefaults.standard.set(value, forKey: name)
        } else if let encoded = encodeToData(value) {
            UserDefaults.standard.set(encoded, forKey: name)
        }
    }
    
    func binding(default defaultValue: T) -> Binding<T> {
        Binding(
            get: {
                self.getValue() ?? defaultValue
            },
            set: { newValue in
                self.set(newValue)
            }
        )
    }
    
    var value: T {
        get { getValue() ?? (uddefault as! T) }
        set { self.set(newValue) }
    }
    
    private func getValue() -> T? {
        if let directValue = UserDefaults.standard.object(forKey: name) as? T {
            return directValue
        }
        
        if let data = UserDefaults.standard.data(forKey: name),
           let decoded = decodeFromData(data, as: T.self) {
            return decoded
        }
        
        return nil
    }

    private func set(_ value: Any?) {
        guard let value = value else {
            UserDefaults.standard.removeObject(forKey: name)
            parent?.objectWillChange.send()
            return
        }
        
        parent?.objectWillChange.send()
        
        if isPropertyListCompatible(value) {
            UserDefaults.standard.set(value, forKey: name)
        } else if let encoded = encodeToData(value) {
            UserDefaults.standard.set(encoded, forKey: name)
        } else {
            print("Warning: Unable to store value for key '\(name)' - not PropertyList compatible and encoding failed")
        }
        
        parent?.objectWillChange.send()
    }
    
    private func isPropertyListCompatible(_ value: Any) -> Bool {
        if value is String || value is Int || value is Float ||
           value is Double || value is Bool || value is Date ||
           value is Data || value is NSNumber {
            return true
        }
        
        if let array = value as? [Any] {
            return array.allSatisfy { isPropertyListCompatible($0) }
        }
        
        if let dict = value as? [String: Any] {
            return dict.values.allSatisfy { isPropertyListCompatible($0) }
        }
        
        if value is URL {
            return true
        }
        
        return false
    }
    
    private func encodeToData<U>(_ value: U) -> Data? {
        if let nsCodingValue = value as? NSCoding {
            return try? NSKeyedArchiver.archivedData(withRootObject: nsCodingValue, requiringSecureCoding: false)
        }
        
        if let codableValue = value as? Encodable {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            return try? encoder.encode(codableValue)
        }
        
        if let codableValue = value as? Encodable {
            return try? JSONEncoder().encode(codableValue)
        }
        
        return nil
    }
    
    private func decodeFromData<U>(_ data: Data, as type: U.Type) -> U? {
        if let decoded = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? U {
            return decoded
        }
        
        if let decodableType = type as? Decodable.Type {
            let decoder = PropertyListDecoder()
            if let decoded = try? decoder.decode(decodableType, from: data) as? U {
                return decoded
            }
        }
        
        if let decodableType = type as? Decodable.Type {
            if let decoded = try? JSONDecoder().decode(decodableType, from: data) as? U {
                return decoded
            }
        }
        
        return nil
    }
    
    static func getOrCreateSetting(named name: String, default defaultValue: T?, self: NativeSettingsManager?) -> Setting<T> {
        if let setting = self?.settings.first(where: { ($0 as? Setting<T>)?.name == name}) as? Setting<T> {
            return setting
        }
        
        let setting = Setting<T>(name: name, defaultAny: defaultValue, parent: self)
        self?.settings.insert(setting)
        return setting
    }
}

extension Setting where T: Equatable {
    static func == (lhs: Setting<T>, rhs: T) -> Bool {
        lhs.value == rhs
    }

    static func == (lhs: T, rhs: Setting<T>) -> Bool {
        lhs == rhs.value
    }

    var wrappedValue: T { value }
}

extension Setting where T == Bool {
    static prefix func ! (setting: Setting<Bool>) -> Bool {
        !setting.value
    }
}
