//
//  SettingsSection.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import SwiftUI

struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    let content: Content
    
    init(title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.weight(.bold))
                .padding(.horizontal)
            
            content
        }
    }
}
