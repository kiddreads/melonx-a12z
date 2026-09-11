//
//  CategoryButton.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import SwiftUI

struct CategoryButton: View {
    let title: LocalizedStringKey
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .blue : .secondary)
            .frame(width: 70, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            )
            .animation(.bouncy(duration: 0.3), value: isSelected)
        }
    }
}
