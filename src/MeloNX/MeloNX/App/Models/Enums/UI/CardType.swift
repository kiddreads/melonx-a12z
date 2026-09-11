//
//  CardType.swift
//  MeloNX
//
//  Created by Stossy11 on 26/11/2025.
//

import Foundation

public enum CardType: Codable, CaseIterable {
    case list
    case card
    case compactCard
    case compactCardNoBackground
    case compactCardSmall

    var displayName: String {
        switch self {
        case .list: "List"
        case .card: "Card"
        case .compactCard: "Compact Card"
        case .compactCardNoBackground: "Compact Card (No Background)"
        case .compactCardSmall: "Compact Card (Small)"
        }
    }
}

