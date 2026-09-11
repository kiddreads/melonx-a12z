//
//  Runner.swift
//  MeloNX
//
//  Created by Stossy11 on 16/12/2025.
//

import Foundation

final class Runner {
    private var task: Task<Void, Never>?

    func start(_ body: @escaping () -> Void) {
        task = Task.detached(priority: .userInitiated) {
            body()
        }
    } 

    func stop() {
        task?.cancel()
    }
}
