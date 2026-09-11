//
//  MemoryUsageMonitor.swift
//  MeloNX
//
//  Created by Stossy11 on 21/12/2024.
//

import Foundation
import SwiftUI

@MainActor
class MemoryUsageMonitor: ObservableObject {
    @Published private(set) var memoryUsage: UInt64 = 0
    private var task: Task<Void, Never>?

    init() {
        task = Task {
            await monitorMemoryUsage()
        }
    }

    deinit {
        task?.cancel()
    }

    private func monitorMemoryUsage() async {
        while !Task.isCancelled {
            updateMemoryUsage()
            try? await Task.sleep(nanoseconds: 200_000_000) 
        }
    }

    private func updateMemoryUsage() {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.stride) / 4

        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            memoryUsage = taskInfo.phys_footprint
        } else {
            print("Failed to get memory usage: \(result)")
            memoryUsage = 0
        }
    }

    func formatMemorySize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
