//
//  matchedTransitionSource.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import SwiftUI

extension View {
    @ViewBuilder
    func iOS18MatchedTransitionSource<T: Hashable>(id: T, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self.matchedGeometryEffect(id: id, in: namespace)
        }
    }
}
