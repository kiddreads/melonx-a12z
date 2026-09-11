//
//  InfoCard.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import SwiftUI

struct InfoCard: View {
    let title: LocalizedStringKey
    let value: LocalizedStringKey 
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}
