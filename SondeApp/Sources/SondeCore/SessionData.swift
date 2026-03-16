import Foundation

/// Cost breakdown for a single model used during a session.
public struct ModelCostEntry: Equatable, Sendable {
    public var model: String
    public var cost: Double

    public init(model: String, cost: Double) {
        self.model = model
        self.cost = cost
    }
}

/// Live session data scraped from Claude Code's state.
public struct SessionData: Equatable, Sendable {
    public var modelName: String?
    public var sessionCost: Double?
    public var contextUsedPct: Double?
    public var contextWindowSize: Int?
    public var totalInputTokens: Int?
    public var totalOutputTokens: Int?
    public var sessionDurationMs: Int?
    public var costPerModel: [ModelCostEntry] = []
    public var gitBranch: String?

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
        // Keep last known good data if new parse found nothing
        // (happens mid-generation when transcript tail has incomplete entries)
        if data.modelName != nil {
            cached = data
        }
        lastRead = Date()
        return cached ?? data
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
        let readSize: UInt64 = min(fileSize, 65536)
        handle.seek(toFileOffset: fileSize - readSize)
        let tailData = handle.readDataToEndOfFile()

        guard let tail = String(data: tailData, encoding: .utf8) else {
            return session
        }

        // Parse JSON lines from the tail, looking for assistant turns with model/usage
        var totalInputTokens = 0
        var totalOutputTokens = 0
        var costByModel: [String: Double] = [:]

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

                // Token usage + per-model cost from message.usage
                if let usage = message["usage"] as? [String: Any] {
                    let input = (usage["input_tokens"] as? Int ?? 0)
                        + (usage["cache_read_input_tokens"] as? Int ?? 0)
                        + (usage["cache_creation_input_tokens"] as? Int ?? 0)
                    let output = usage["output_tokens"] as? Int ?? 0
                    totalInputTokens += input
                    totalOutputTokens += output

                    if let model = message["model"] as? String {
                        let name = displayName(for: model)
                        let cost = Self.calculateCost(model: name, input: input, output: output)
                        costByModel[name, default: 0] += cost
                    }
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

            // Stop once we have enough data (but scan at least a few lines for tokens)
            if session.modelName != nil && totalInputTokens > 1000 {
                break
            }
        }

        if totalInputTokens > 0 { session.totalInputTokens = totalInputTokens }
        if totalOutputTokens > 0 { session.totalOutputTokens = totalOutputTokens }

        // Per-model cost breakdown
        session.costPerModel = costByModel.map { ModelCostEntry(model: $0.key, cost: $0.value) }
        let totalCost = costByModel.values.reduce(0, +)
        if totalCost > 0 && session.sessionCost == nil { session.sessionCost = totalCost }

        // Extract project directory from transcript path and detect git branch.
        // Transcript path: ~/.claude/projects/<encoded-project-path>/<uuid>.jsonl
        // The project folder name is the URL-encoded absolute path of the project.
        session.gitBranch = detectGitBranch(from: transcript)

        return session
    }

    private func detectGitBranch(from transcriptURL: URL) -> String? {
        // Transcript: ~/.claude/projects/-Users-foo-project/uuid.jsonl
        // The parent dir name is the URL-encoded project path (dashes for slashes)
        let projectDir = transcriptURL.deletingLastPathComponent().lastPathComponent
        // Convert "-Users-foo-project" back to "/Users/foo/project"
        let decoded = "/" + projectDir.dropFirst().replacingOccurrences(of: "-", with: "/")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
        process.currentDirectoryURL = URL(fileURLWithPath: decoded)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch { return nil }

        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let branch = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return branch?.isEmpty == true ? nil : branch
    }

    private static func calculateCost(model: String, input: Int, output: Int) -> Double {
        let (inPrice, outPrice): (Double, Double) = switch model {
        case "Opus": (15.0, 75.0)
        case "Sonnet": (3.0, 15.0)
        case "Haiku": (0.25, 1.25)
        default: (3.0, 15.0)
        }
        return (Double(input) / 1_000_000) * inPrice + (Double(output) / 1_000_000) * outPrice
    }

    private func displayName(for modelId: String) -> String {
        if modelId.contains("opus") { return "Opus" }
        if modelId.contains("sonnet") { return "Sonnet" }
        if modelId.contains("haiku") { return "Haiku" }
        return modelId
    }
}
