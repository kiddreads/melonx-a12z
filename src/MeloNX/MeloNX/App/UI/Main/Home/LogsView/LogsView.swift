//
//  LogsView.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import SwiftUI

struct LogView: View {
    @StateObject var logsModel = LogCapture.shared
    @State var logs: [String] = []
    @State private var showingLogs = false
    
    public var isfps: Bool
    
    private let fileManager = FileManager.default
    private let maxDisplayLines = 4
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(logs.suffix(maxDisplayLines), id: \.self) { log in
                Text(log)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                    .transition(.opacity)
            }
        }
        .padding()
        .task {
            for await log in LogCapture.shared.logs {
                logs.append(log)
            }
        }
    }
    
    private func stopLogFileWatching() {
        showingLogs = false
    }
}



