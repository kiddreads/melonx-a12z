//
//  CategoryRow.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import SwiftUI

struct CategoryRow: View {
    let category: SettingsViewNew.SettingsCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Rectangle()
                .frame(width: 2.5, height: 35)
                .foregroundStyle(isSelected ? Color.accentColor : Color.clear)
            Text(category.rawValue)
            Spacer()
        }
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .padding(5)
        .background(
            Color(uiColor: .secondarySystemBackground).opacity(isSelected ? 1 : 0)
        )
        .background(
            Rectangle()
                .stroke(isSelected ? .teal : .clear, lineWidth: 2.5)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}
