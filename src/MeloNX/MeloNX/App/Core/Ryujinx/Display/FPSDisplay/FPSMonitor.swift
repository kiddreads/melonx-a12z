//
//  FPSMonitor.swift
//  MeloNX
//
//  Created by Stossy11 on 21/12/2024.
//

import Foundation
import Combine

@MainActor
class FPSMonitor: ObservableObject {
    @Published private(set) var currentFPS: UInt64 = 0
    private var task: Task<Void, Never>?

    init() {
        task = Task {
            await monitorFPS()
        }
    }

    deinit {
        task?.cancel()
    }

    private func monitorFPS() async {
        while !Task.isCancelled {
            let currentfps = UInt64(RyujinxBridge.currentFPS)
            currentFPS = currentfps

            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    func formatFPS() -> String {
        String(format: "FPS: %.2f", Double(currentFPS))
    }
}
