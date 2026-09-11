//
//  LogCapture.swift
//  MeloNX
//
//  Created by Stossy11 on 22/09/2025.
//


import Foundation

final class LogCapture: ObservableObject {
    static let shared = LogCapture()

    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private let originalStdout: Int32
    private let originalStderr: Int32

    private var continuation: AsyncStream<String>.Continuation?
    public private(set) var capturedLogs: [String] = []

    lazy var logs: AsyncStream<String> = {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.onTermination = { _ in
                self.continuation = nil
            }
        }
    }()

    private init() {
        originalStdout = dup(STDOUT_FILENO)
        originalStderr = dup(STDERR_FILENO)
        startCapturing()
    }

    func startCapturing() {
        stdoutPipe = Pipe()
        stderrPipe = Pipe()

        redirectOutput(to: stdoutPipe!, fileDescriptor: STDOUT_FILENO)
        redirectOutput(to: stderrPipe!, fileDescriptor: STDERR_FILENO)

        setupReadabilityHandler(for: stdoutPipe!, isStdout: true)
        setupReadabilityHandler(for: stderrPipe!, isStdout: false)
    }

    func stopCapturing() {
        dup2(originalStdout, STDOUT_FILENO)
        dup2(originalStderr, STDERR_FILENO)

        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
    }

    private func redirectOutput(to pipe: Pipe, fileDescriptor: Int32) {
        dup2(pipe.fileHandleForWriting.fileDescriptor, fileDescriptor)
    }

    private func setupReadabilityHandler(for pipe: Pipe, isStdout: Bool) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            guard let self else { return }

            let data = fileHandle.availableData
            let originalFD = isStdout ? self.originalStdout : self.originalStderr
            write(originalFD, (data as NSData).bytes, data.count)

            guard let logString = String(data: data, encoding: .utf8),
                  let cleanedLog = self.cleanLog(logString),
                  !cleanedLog.0.isEmpty else { return }

            self.capturedLogs.append(cleanedLog.1)
            self.continuation?.yield(cleanedLog.0) 

        }
    }

    private func cleanLog(_ raw: String) -> (String, String)? {
        let lines = raw.split(separator: "\n")
        
        let filteredLines = lines.filter { line in
            if UserDefaults.standard.bool(forKey: "showFullLogs") {
                return true
            }
            
            let regex = try? NSRegularExpression(pattern: "\\d{2}:\\d{2}:\\d{2}\\.\\d{3} \\|[A-Z]+\\|", options: .caseInsensitive)
            let matches = regex?.matches(in: String(line), options: [], range: NSRange(location: 0, length: line.utf16.count)) ?? []
            
            return matches.count >= 1
        }

        let cleaned = filteredLines.map { line -> String in
            if let tabRange = line.range(of: "\t") {
                return line[tabRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return line.trimmingCharacters(in: .whitespacesAndNewlines)
        }.joined(separator: "\n")
        
        
        let cleaned2 = lines.map { line -> String in
            if let tabRange = line.range(of: "\t") {
                return line[tabRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return line.trimmingCharacters(in: .whitespacesAndNewlines)
        }.joined(separator: "\n")

        return cleaned.isEmpty ? nil : (cleaned.replacingOccurrences(of: "\n\n", with: "\n"), cleaned2)
    }

    deinit {
        stopCapturing()
        continuation?.finish()
    }
}
