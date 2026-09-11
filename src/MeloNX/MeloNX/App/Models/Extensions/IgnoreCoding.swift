//
//  IgnoreCoding.swift
//  MeloNX
//
//  Created by Stossy11 on 09/11/2025.
//

import Foundation

@propertyWrapper
struct IgnoreCoding<Value>: Codable where Value: Codable {
    var wrappedValue: Value

    init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        if Value.self == String.self {
            self.wrappedValue = "" as! Value
            return
        } else if Value.self == [String].self {
            self.wrappedValue = [] as! Value
            return
        }

        throw DecodingError.dataCorrupted(
            .init(
                codingPath: decoder.codingPath,
                debugDescription: "need to add support for \(Value.self)"
            )
        )
    }


    func encode(to encoder: Encoder) throws {
        
    }
}
