import Foundation

/// Represents a running Claude Code session.
public struct AgentSession: Identifiable, Sendable {
    public let id: Int32  // PID
    public let command: String
    public let startTime: Date?

    public init(id: Int32, command: String, startTime: Date?) {
        self.id = id
        self.command = command
        self.startTime = startTime
    }
}

/// Watches for running Claude Code processes.
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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-eo", "pid,lstart,command"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var sessions: [AgentSession] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE MMM dd HH:mm:ss yyyy"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        for line in output.split(separator: "\n").dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("claude") || trimmed.contains("Claude") else { continue }
            // Skip our own grep/ps
            guard !trimmed.contains("ps -eo") else { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard let pidStr = parts.first, let pid = Int32(pidStr) else { continue }

            let rest = parts.count > 1 ? String(parts[1]) : ""
            sessions.append(AgentSession(id: pid, command: rest, startTime: nil))
        }

        return sessions
    }
}
