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

/// Cost tracked per project (worktree).
public struct ProjectCost: Equatable, Sendable {
    public var name: String
    public var cost: Double

    public init(name: String, cost: Double) {
        self.name = name
        self.cost = cost
    }
}

/// Detailed session data for a single project.
public struct ProjectSession: Identifiable, Equatable, Sendable {
    public var id: String  // encoded directory name
    public var name: String  // decoded project name
    public var modelName: String?
    public var sessionCost: Double?
    public var contextUsedPct: Double?
    public var totalInputTokens: Int?
    public var totalOutputTokens: Int?
    public var contextWindowSize: Int?
    public var gitBranch: String?
    public var lastActivity: Date?

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    public var contextTokensUsed: Int {
        (totalInputTokens ?? 0) + (totalOutputTokens ?? 0)
    }

    public var formattedCost: String {
        guard let cost = sessionCost else { return "--" }
        if cost < 0.01 { return String(format: "$%.3f", cost) }
        return String(format: "$%.2f", cost)
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
    public var otherProjects: [ProjectCost] = []

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
    private var cachedProjects: [ProjectSession] = []
    private var lastRead: Date?
    private let readInterval: TimeInterval = 5

    public init() {}

    public func getAllProjects() -> [ProjectSession] {
        return cachedProjects
    }

    public func getSessionData() async -> SessionData {
        if let cached, let lastRead, Date().timeIntervalSince(lastRead) < readInterval {
            return cached
        }

        // Prefer Rust binary's authoritative session cache (cost, context, model)
        var data = readFromRustSessionCache() ?? readFromClaudeState()

        // Supplement with transcript data for fields Rust doesn't provide
        let transcriptData = readFromClaudeState()
        if data.gitBranch == nil { data.gitBranch = transcriptData.gitBranch }
        if data.otherProjects.isEmpty { data.otherProjects = transcriptData.otherProjects }

        // Keep last known good data if new parse found nothing
        if data.modelName != nil {
            cached = data
        }
        lastRead = Date()
        return cached ?? data
    }

    /// Read authoritative session data from the Rust binary's cache.
    /// The Rust statusline writes ~/Library/Caches/sonde/session_data.json
    /// on every render with the exact data from Claude Code's stdin JSON.
    private func readFromRustSessionCache() -> SessionData? {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let path = cacheDir.appendingPathComponent("sonde/session_data.json")
        guard let raw = try? Data(contentsOf: path),
              let envelope = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
              let data = envelope["data"] as? [String: Any]
        else {
            return nil
        }

        var session = SessionData()
        session.modelName = data["model_name"] as? String
        session.sessionCost = data["session_cost"] as? Double
        session.contextUsedPct = data["context_used_pct"] as? Double
        session.contextWindowSize = data["context_window_size"] as? Int
        session.totalInputTokens = data["total_input_tokens"] as? Int
        session.totalOutputTokens = data["total_output_tokens"] as? Int
        session.sessionDurationMs = data["session_duration_ms"] as? Int

        return session.modelName != nil ? session : nil
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

        // Find ALL .jsonl transcripts modified in the last 5 minutes
        let now = Date()
        var recentTranscripts: [(url: URL, date: Date)] = []

        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension == "jsonl",
                  !url.path.contains("/subagents/")
            else { continue }
            if let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = values.contentModificationDate,
               now.timeIntervalSince(modDate) < 300
            {
                recentTranscripts.append((url: url, date: modDate))
            }
        }

        guard !recentTranscripts.isEmpty else {
            return session
        }

        // Sort by date descending — first entry is the primary (most recent)
        recentTranscripts.sort { $0.date > $1.date }

        let primaryTranscript = recentTranscripts[0].url

        // Parse primary transcript into session data
        parseTranscript(primaryTranscript, into: &session)

        // Extract project directory from transcript path and detect git branch.
        session.gitBranch = detectGitBranch(from: primaryTranscript)

        // Collect cost data from other active transcripts (group by project)
        var costByProject: [String: Double] = [:]
        let primaryProjectDir = primaryTranscript.deletingLastPathComponent().lastPathComponent

        for entry in recentTranscripts {
            let projectDir = entry.url.deletingLastPathComponent().lastPathComponent
            let cost = quickParseCost(from: entry.url)
            costByProject[projectDir, default: 0] += cost
        }

        // Build otherProjects from non-primary projects
        var otherProjects: [ProjectCost] = []
        for (projectDir, cost) in costByProject {
            if projectDir == primaryProjectDir { continue }
            let name = Self.decodeProjectName(projectDir)
            otherProjects.append(ProjectCost(name: name, cost: cost))
        }
        session.otherProjects = otherProjects.sorted { $0.cost > $1.cost }

        // Build detailed allProjects list (group transcripts by project dir)
        var transcriptsByProject: [String: [(url: URL, date: Date)]] = [:]
        for entry in recentTranscripts {
            let projectDir = entry.url.deletingLastPathComponent().lastPathComponent
            transcriptsByProject[projectDir, default: []].append(entry)
        }

        var allProjects: [ProjectSession] = []
        for (projectDir, transcripts) in transcriptsByProject {
            let name = Self.decodeProjectName(projectDir)
            var project = ProjectSession(id: projectDir, name: name)

            // Parse the most recent transcript for this project for detailed data
            let sorted = transcripts.sorted { $0.date > $1.date }
            project.lastActivity = sorted.first?.date

            // Parse the most recent transcript to get model/tokens/cost
            var projSession = SessionData()
            parseTranscript(sorted[0].url, into: &projSession)
            project.modelName = projSession.modelName
            project.totalInputTokens = projSession.totalInputTokens
            project.totalOutputTokens = projSession.totalOutputTokens
            project.contextWindowSize = projSession.contextWindowSize

            // Sum cost across all transcripts for this project
            var totalCost: Double = 0
            for t in sorted {
                totalCost += quickParseCost(from: t.url)
            }
            if totalCost > 0 { project.sessionCost = totalCost }
            else if let sc = projSession.sessionCost { project.sessionCost = sc }

            // Context pct
            if let windowSize = projSession.contextWindowSize, windowSize > 0 {
                project.contextUsedPct = Double(project.contextTokensUsed) / Double(windowSize) * 100
            } else if let pct = projSession.contextUsedPct {
                project.contextUsedPct = pct
            }

            // Git branch
            project.gitBranch = detectGitBranch(from: sorted[0].url)

            allProjects.append(project)
        }

        cachedProjects = allProjects.sorted { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }

        return session
    }

    /// Decode a Claude project directory name back to a readable project name.
    /// Claude encodes absolute paths by replacing `/` with `-`, e.g.
    /// `/Users/ron/Documents/GitHub/kav-siddur` becomes `-Users-ron-Documents-GitHub-kav-siddur`.
    /// We cannot perfectly reverse the encoding because dashes in folder names are
    /// indistinguishable from path separators. Instead, we look for well-known path
    /// markers (e.g. "GitHub-", "projects-") and take the remainder as the project name,
    /// preserving any original dashes.
    private static func decodeProjectName(_ encoded: String) -> String {
        // Known markers that typically precede the project folder name.
        // Order matters: check more specific markers first.
        let markers = ["GitHub-", "Projects-", "projects-", "repos-", "src-", "code-", "Developer-"]
        for marker in markers {
            if let range = encoded.range(of: marker, options: .caseInsensitive) {
                let remainder = encoded[range.upperBound...]
                if !remainder.isEmpty {
                    return String(remainder)
                }
            }
        }
        // Fallback: return everything after the last recognized path segment.
        // Split on "-" and take from the last capitalized segment onward,
        // or just the last component if nothing else works.
        let parts = encoded.drop(while: { $0 == "-" }).split(separator: "-", omittingEmptySubsequences: true)
        if parts.count > 1 {
            return String(parts.last!)
        }
        return encoded
    }

    /// Parse a transcript file and populate session data (model, cost, tokens, etc.).
    private func parseTranscript(_ transcript: URL, into session: inout SessionData) {
        guard let handle = try? FileHandle(forReadingFrom: transcript) else {
            return
        }
        defer { handle.closeFile() }

        let fileSize = handle.seekToEndOfFile()
        let readSize: UInt64 = min(fileSize, 65536)
        handle.seek(toFileOffset: fileSize - readSize)
        let tailData = handle.readDataToEndOfFile()

        guard let tail = String(data: tailData, encoding: .utf8) else {
            return
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

            // Don't break early — scan all lines in tail to accumulate full cost
        }

        if totalInputTokens > 0 { session.totalInputTokens = totalInputTokens }
        if totalOutputTokens > 0 { session.totalOutputTokens = totalOutputTokens }

        // Per-model cost breakdown
        session.costPerModel = costByModel.map { ModelCostEntry(model: $0.key, cost: $0.value) }
        let totalCost = costByModel.values.reduce(0, +)
        if totalCost > 0 && session.sessionCost == nil { session.sessionCost = totalCost }
    }

    /// Quick parse of a transcript to extract just the total cost.
    private func quickParseCost(from transcript: URL) -> Double {
        guard let handle = try? FileHandle(forReadingFrom: transcript) else { return 0 }
        defer { handle.closeFile() }

        let fileSize = handle.seekToEndOfFile()
        let readSize: UInt64 = min(fileSize, 65536)
        handle.seek(toFileOffset: fileSize - readSize)
        let tailData = handle.readDataToEndOfFile()

        guard let tail = String(data: tailData, encoding: .utf8) else { return 0 }

        var totalCost: Double = 0
        var costFromTracker: Double?

        for line in tail.split(separator: "\n").reversed() {
            guard let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
            else { continue }

            if let message = obj["message"] as? [String: Any],
               let usage = message["usage"] as? [String: Any],
               let model = message["model"] as? String {
                let input = (usage["input_tokens"] as? Int ?? 0)
                    + (usage["cache_read_input_tokens"] as? Int ?? 0)
                    + (usage["cache_creation_input_tokens"] as? Int ?? 0)
                let output = usage["output_tokens"] as? Int ?? 0
                let name = displayName(for: model)
                totalCost += Self.calculateCost(model: name, input: input, output: output)
            }

            if costFromTracker == nil,
               let costTracker = obj["costTracker"] as? [String: Any],
               let cost = costTracker["totalCost"] as? Double {
                costFromTracker = cost
            }
        }

        return costFromTracker ?? totalCost
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
