//
//  InfoButton.swift
//  MeloNX
//
//  Created by Stossy11 on 22/12/2025.
//

import SwiftUI

struct InfoButton: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @Binding var isPresented: Bool
    
    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .alert(isPresented: $isPresented) {
            Alert(
                title: Text(title),
                message: Text(message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
