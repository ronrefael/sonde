import Foundation

/// Represents a running Claude Code session.
public struct AgentSession: Identifiable, Equatable, Sendable {
    public let id: Int32 // PID
    public let command: String

    public init(id: Int32, command: String) {
        self.id = id
        self.command = command
    }
}

/// Watches for running Claude Code processes using pgrep.
public actor AgentWatcher {
    private var cachedSessions: [AgentSession] = []
    private var lastScan: Date?
    private let scanInterval: TimeInterval = 10

    public init() {}

    public func getActiveSessions() async -> [AgentSession] {
        if let lastScan, Date().timeIntervalSince(lastScan) < scanInterval {
            return cachedSessions
        }

        let sessions = scanProcesses()
        cachedSessions = sessions
        lastScan = Date()
        return sessions
    }

    private func scanProcesses() -> [AgentSession] {
        // Use pgrep for efficient filtering (matches Rust active_sessions.rs approach)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-fl", "claude"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == 0 else { return [] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var sessions: [AgentSession] = []
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            // Skip our own pgrep process
            guard !trimmed.contains("pgrep") else { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard let pidStr = parts.first, let pid = Int32(pidStr) else { continue }
            let cmd = parts.count > 1 ? String(parts[1]) : ""
            sessions.append(AgentSession(id: pid, command: cmd))
        }

        return sessions
    }
}
