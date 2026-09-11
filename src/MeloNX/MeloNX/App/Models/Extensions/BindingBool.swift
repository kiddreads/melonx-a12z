//
//  BindingBool.swift
//  MeloNX
//
//  Created by Stossy11 on 20/07/2025.
//

import SwiftUI

extension Binding where Value == Bool {
    var reversed: Binding<Bool> {
        Binding<Bool>(
            get: { !self.wrappedValue },
            set: { self.wrappedValue = !$0 }
        )
    }
}
