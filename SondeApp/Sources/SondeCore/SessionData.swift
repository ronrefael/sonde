import Foundation

/// Live session data scraped from Claude Code's state.
public struct SessionData: Equatable, Sendable {
    public var modelName: String?
    public var sessionCost: Double?
    public var contextUsedPct: Double?
    public var contextWindowSize: Int?
    public var totalInputTokens: Int?
    public var totalOutputTokens: Int?
    public var sessionDurationMs: Int?

    public init() {}

    public var contextTokensUsed: Int {
        (totalInputTokens ?? 0) + (totalOutputTokens ?? 0)
    }

    public var formattedCost: String {
        guard let cost = sessionCost else { return "--" }
        if cost < 0.01 { return String(format: "$%.3f", cost) }
        return String(format: "$%.2f", cost)
    }

    public var formattedDuration: String {
        guard let ms = sessionDurationMs else { return "--" }
        let secs = ms / 1000
        let hours = secs / 3600
        let mins = (secs % 3600) / 60
        if hours > 0 { return "\(hours)h\(String(format: "%02d", mins))m" }
        if mins > 0 { return "\(mins)m\(String(format: "%02d", secs % 60))s" }
        return "\(secs)s"
    }
}

/// Reads session data from the Rust binary's stdin cache or Claude Code state.
public actor SessionReader {
    private var cached: SessionData?
    private var lastRead: Date?
    private let readInterval: TimeInterval = 5

    public init() {}

    public func getSessionData() async -> SessionData {
        if let cached, let lastRead, Date().timeIntervalSince(lastRead) < readInterval {
            return cached
        }

        let data = readFromClaudeState()
        cached = data
        lastRead = Date()
        return data
    }

    /// Try to read session state from Claude Code's process or recent transcript.
    private func readFromClaudeState() -> SessionData {
        var session = SessionData()

        // Find most recent Claude project directory
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")

        guard let enumerator = FileManager.default.enumerator(
            at: claudeDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return session
        }

        // Find the most recently modified .jsonl (UUID-named, not in subagents/)
        var bestTranscript: URL?
        var bestDate: Date = .distantPast

        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension == "jsonl",
                  !url.path.contains("/subagents/")
            else { continue }
            if let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = values.contentModificationDate,
               modDate > bestDate
            {
                bestDate = modDate
                bestTranscript = url
            }
        }

        guard let transcript = bestTranscript,
              // Only read if modified in last 5 minutes (active session)
              Date().timeIntervalSince(bestDate) < 300
        else {
            return session
        }

        // Read last few KB of transcript for recent state
        guard let handle = try? FileHandle(forReadingFrom: transcript) else {
            return session
        }
        defer { handle.closeFile() }

        let fileSize = handle.seekToEndOfFile()
        let readSize: UInt64 = min(fileSize, 8192)
        handle.seek(toFileOffset: fileSize - readSize)
        let tailData = handle.readDataToEndOfFile()

        guard let tail = String(data: tailData, encoding: .utf8) else {
            return session
        }

        // Parse JSON lines from the tail, looking for assistant turns with model/usage
        var totalInputTokens = 0
        var totalOutputTokens = 0

        for line in tail.split(separator: "\n").reversed() {
            guard let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
            else { continue }

            // Claude Code transcript format: { type: "assistant", message: { model, usage } }
            if let message = obj["message"] as? [String: Any] {
                // Model from message.model
                if session.modelName == nil, let model = message["model"] as? String {
                    session.modelName = displayName(for: model)
                }

                // Token usage from message.usage
                if let usage = message["usage"] as? [String: Any] {
                    let input = (usage["input_tokens"] as? Int ?? 0)
                        + (usage["cache_read_input_tokens"] as? Int ?? 0)
                        + (usage["cache_creation_input_tokens"] as? Int ?? 0)
                    let output = usage["output_tokens"] as? Int ?? 0
                    totalInputTokens += input
                    totalOutputTokens += output
                }
            }

            // costTracker if present (some transcript formats)
            if let costTracker = obj["costTracker"] as? [String: Any] {
                if session.sessionCost == nil, let cost = costTracker["totalCost"] as? Double {
                    session.sessionCost = cost
                }
                if session.sessionDurationMs == nil, let dur = costTracker["totalDurationMs"] as? Int {
                    session.sessionDurationMs = dur
                }
            }

            // Break if we have model (tokens accumulate from multiple lines)
            if session.modelName != nil && totalInputTokens > 0 {
                break
            }
        }

        if totalInputTokens > 0 { session.totalInputTokens = totalInputTokens }
        if totalOutputTokens > 0 { session.totalOutputTokens = totalOutputTokens }

        return session
    }

    private func displayName(for modelId: String) -> String {
        if modelId.contains("opus") { return "Opus" }
        if modelId.contains("sonnet") { return "Sonnet" }
        if modelId.contains("haiku") { return "Haiku" }
        return modelId
    }
}
