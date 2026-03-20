import Foundation
import os.log

private let logger = Logger(subsystem: "dev.sonde.app", category: "SessionReader")

/// Returns the real (non-sandboxed) home directory.
/// Inside a sandbox, homeDirectoryForCurrentUser points to the container.
/// Use pw_dir from getpwuid to get the real home.
private func realHomeDir() -> URL {
    if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
        return URL(fileURLWithPath: String(cString: dir))
    }
    return FileManager.default.homeDirectoryForCurrentUser
}

/// Returns the real (non-sandboxed) ~/Library/Caches/sonde directory.
private func realSondeCacheDir() -> URL {
    realHomeDir().appendingPathComponent("Library/Caches/sonde")
}

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

/// Per-task (conversation) detail within a project.
public struct TaskInfo: Identifiable, Equatable, Sendable {
    public var id: String  // filename (UUID)
    public var title: String  // first user message, truncated to 60 chars
    public var modelName: String?
    public var inputTokens: Int = 0
    public var outputTokens: Int = 0
    public var cacheReadTokens: Int = 0
    public var cacheWriteTokens: Int = 0
    public var estimatedCost: Double = 0
    public var lastActivity: Date?
    public var messageCount: Int = 0

    public var totalTokens: Int { inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens }

    public var formattedTokens: String {
        let t = totalTokens
        if t >= 1_000_000 {
            return String(format: "%.1fM", Double(t) / 1_000_000)
        }
        if t >= 1000 {
            return String(format: "%.0fk", Double(t) / 1000)
        }
        return "\(t)"
    }

    public var formattedCost: String {
        if estimatedCost < 0.01 { return String(format: "$%.3f", estimatedCost) }
        return String(format: "$%.2f", estimatedCost)
    }

    public init(id: String, title: String) {
        self.id = id
        self.title = title
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
    public var tasks: [TaskInfo] = []

    // Stats from transcript parsing
    public var linesAdded: Int?
    public var linesRemoved: Int?
    public var cacheReadTokens: Int = 0
    public var cacheWriteTokens: Int = 0
    public var webSearchCount: Int = 0
    public var webFetchCount: Int = 0
    public var messageCount: Int = 0

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

    public var totalLinesChanged: Int {
        (linesAdded ?? 0) + (linesRemoved ?? 0)
    }

    public var codeVelocity: String? {
        // No duration available per-project, so no velocity
        nil
    }

    public var costPerLine: String? {
        guard totalLinesChanged > 0, let cost = sessionCost, cost > 0 else { return nil }
        let cpl = cost / Double(totalLinesChanged)
        return String(format: "$%.2f/line", cpl)
    }

    public var cacheHitRatio: String? {
        let total = cacheReadTokens + cacheWriteTokens
        guard total > 0 else { return nil }
        let ratio = Double(cacheReadTokens) / Double(total) * 100
        return "\(Int(ratio))%"
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

    // Session identity (for multi-session support)
    public var sessionId: String?
    public var projectPath: String?

    // Stats from Rust session cache
    public var linesAdded: Int?
    public var linesRemoved: Int?
    public var apiDurationMs: Int?
    public var claudeVersion: String?
    public var agentName: String?
    public var vimMode: String?

    // Stats from transcript parsing
    public var cacheReadTokens: Int = 0
    public var cacheWriteTokens: Int = 0
    public var webSearchCount: Int = 0
    public var webFetchCount: Int = 0
    public var messageCount: Int = 0

    public init() {}

    /// Display-friendly project name derived from the working directory path.
    public var projectName: String? {
        guard let path = projectPath else { return nil }
        return (path as NSString).lastPathComponent
    }

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

    public var totalLinesChanged: Int {
        (linesAdded ?? 0) + (linesRemoved ?? 0)
    }

    /// Lines changed per hour, e.g. "142 lines/hr"
    public var codeVelocity: String? {
        guard totalLinesChanged > 0, let ms = sessionDurationMs, ms > 0 else { return nil }
        let hours = Double(ms) / 3_600_000.0
        guard hours > 0 else { return nil }
        let rate = Int(Double(totalLinesChanged) / hours)
        return "\(rate) lines/hr"
    }

    /// Cost per line changed, e.g. "$0.03/line"
    public var costPerLine: String? {
        guard totalLinesChanged > 0, let cost = sessionCost, cost > 0 else { return nil }
        let cpl = cost / Double(totalLinesChanged)
        return String(format: "$%.2f/line", cpl)
    }

    /// Cache hit ratio, e.g. "87%"
    public var cacheHitRatio: String? {
        let total = cacheReadTokens + cacheWriteTokens
        guard total > 0 else { return nil }
        let ratio = Double(cacheReadTokens) / Double(total) * 100
        return "\(Int(ratio))%"
    }

    /// Cost per hour burn rate, e.g. "$6.40/hr"
    public var costPerHour: String? {
        guard let cost = sessionCost, cost > 0, let ms = sessionDurationMs, ms > 60_000 else { return nil }
        let hours = Double(ms) / 3_600_000.0
        guard hours > 0 else { return nil }
        let rate = cost / hours
        return String(format: "$%.2f/hr", rate)
    }

    /// API wait ratio (time spent waiting for API vs total session), e.g. "12%"
    public var apiWaitRatio: String? {
        guard let apiMs = apiDurationMs, let totalMs = sessionDurationMs, totalMs > 0 else { return nil }
        let ratio = Double(apiMs) / Double(totalMs) * 100
        return "\(Int(ratio))%"
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

    /// Return all active Claude Code sessions from the Rust cache directory.
    /// Each running session writes its own session_<id>.json file.
    public func getAllActiveSessions() -> [SessionData] {
        return readAllRustSessionCaches()
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
        if data.cacheReadTokens == 0 { data.cacheReadTokens = transcriptData.cacheReadTokens }
        if data.cacheWriteTokens == 0 { data.cacheWriteTokens = transcriptData.cacheWriteTokens }
        if data.webSearchCount == 0 { data.webSearchCount = transcriptData.webSearchCount }
        if data.webFetchCount == 0 { data.webFetchCount = transcriptData.webFetchCount }
        if data.messageCount == 0 { data.messageCount = transcriptData.messageCount }

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
        #if os(macOS)
        let path = realSondeCacheDir().appendingPathComponent("session_data.json")
        guard let raw = try? Data(contentsOf: path) else {
            logger.warning("Cannot read session cache at \(path.path)")
            return nil
        }
        guard let envelope = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
              let data = envelope["data"] as? [String: Any]
        else {
            logger.warning("Failed to parse session cache JSON")
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
        session.linesAdded = data["total_lines_added"] as? Int
        session.linesRemoved = data["total_lines_removed"] as? Int
        session.apiDurationMs = data["total_api_duration_ms"] as? Int
        session.claudeVersion = data["version"] as? String
        session.agentName = data["agent_name"] as? String
        // Prefer project_dir (real path) over cwd (avoids decode ambiguity)
        if let projectDir = data["project_dir"] as? String {
            session.projectPath = projectDir
        } else if let cwd = data["cwd"] as? String {
            session.projectPath = cwd
        }
        if let sid = data["session_id"] as? String { session.sessionId = sid }
        if let branch = data["git_branch"] as? String { session.gitBranch = branch }

        return session.modelName != nil ? session : nil
        #else
        return nil
        #endif
    }

    /// Read ALL active session cache files from the Rust binary's cache directory.
    /// Each running Claude Code session writes its own session_<id>.json file.
    /// Filters out stale files (older than 60 seconds).
    private func readAllRustSessionCaches() -> [SessionData] {
        #if os(macOS)
        let sondeDir = realSondeCacheDir()
        let fm = FileManager.default

        guard let contents = try? fm.contentsOfDirectory(
            at: sondeDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let now = Date()
        var sessions: [SessionData] = []

        for fileURL in contents {
            let filename = fileURL.lastPathComponent
            // Match session_*.json but NOT the old session_data.json
            guard filename.hasPrefix("session_"),
                  filename.hasSuffix(".json"),
                  filename != "session_data.json"
            else { continue }

            // Filter out stale files (not updated in 10 minutes)
            // Sessions may not render frequently when idle, so use a generous window
            // Skip stale files but don't delete — Rust manages its own cache cleanup
            if let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = values.contentModificationDate,
               now.timeIntervalSince(modDate) > 600 {
                continue
            }

            guard let raw = try? Data(contentsOf: fileURL),
                  let envelope = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
                  let data = envelope["data"] as? [String: Any]
            else { continue }

            // Check cache envelope expiry — handle both Int and Double from JSON
            let expiresAt: Double?
            if let d = envelope["expires_at"] as? Double {
                expiresAt = d
            } else if let i = envelope["expires_at"] as? Int {
                expiresAt = Double(i)
            } else {
                expiresAt = nil
            }
            if let ea = expiresAt, now.timeIntervalSince1970 > ea { continue }

            var session = SessionData()
            session.modelName = data["model_name"] as? String
            session.sessionCost = data["session_cost"] as? Double
            session.contextUsedPct = data["context_used_pct"] as? Double
            session.contextWindowSize = data["context_window_size"] as? Int
            session.totalInputTokens = data["total_input_tokens"] as? Int
            session.totalOutputTokens = data["total_output_tokens"] as? Int
            session.sessionDurationMs = data["session_duration_ms"] as? Int
            session.linesAdded = data["total_lines_added"] as? Int
            session.linesRemoved = data["total_lines_removed"] as? Int
            session.apiDurationMs = data["total_api_duration_ms"] as? Int
            session.claudeVersion = data["version"] as? String
            session.agentName = data["agent_name"] as? String
            session.vimMode = data["vim_mode"] as? String

            // Store session_id and project path for multi-session display
            if let sessionId = data["session_id"] as? String {
                session.sessionId = sessionId
            }
            // Prefer project_dir (real path) over cwd
            if let projectDir = data["project_dir"] as? String {
                session.projectPath = projectDir
            } else if let cwd = data["cwd"] as? String {
                session.projectPath = cwd
            }
            if let branch = data["git_branch"] as? String {
                session.gitBranch = branch
            }

            if session.modelName != nil {
                sessions.append(session)
            }
        }

        // Sort by cost descending (most expensive session first)
        sessions.sort { ($0.sessionCost ?? 0) > ($1.sessionCost ?? 0) }
        if !sessions.isEmpty {
            logger.debug("Found \(sessions.count) active sessions from cache")
        }
        return sessions
        #else
        return []
        #endif
    }

    /// Try to read session state from Claude Code's process or recent transcript.
    private func readFromClaudeState() -> SessionData {
        var session = SessionData()

        // Find most recent Claude project directory
        // Use realHomeDir() to bypass sandbox container redirection
        let claudeDir = realHomeDir().appendingPathComponent(".claude/projects")

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
            project.linesAdded = projSession.linesAdded
            project.linesRemoved = projSession.linesRemoved
            project.cacheReadTokens = projSession.cacheReadTokens
            project.cacheWriteTokens = projSession.cacheWriteTokens
            project.webSearchCount = projSession.webSearchCount
            project.webFetchCount = projSession.webFetchCount
            project.messageCount = projSession.messageCount

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

            // Parse per-task details
            project.tasks = parseTasksForProject(transcripts: sorted)

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
            return parts.last.map(String.init) ?? encoded
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
        let readSize: UInt64 = min(fileSize, 524288)
        handle.seek(toFileOffset: fileSize - readSize)
        let tailData = handle.readDataToEndOfFile()

        guard let tail = String(data: tailData, encoding: .utf8) else {
            return
        }

        // Parse JSON lines from the tail, looking for assistant turns with model/usage
        var totalInputTokens = 0
        var totalOutputTokens = 0
        var totalCacheRead = 0
        var totalCacheWrite = 0
        var webSearches = 0
        var webFetches = 0
        var assistantMessages = 0
        var costByModel: [String: Double] = [:]

        for line in tail.split(separator: "\n").reversed() {
            guard let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
            else { continue }

            // Claude Code transcript format: { type: "assistant", message: { model, usage } }
            if let message = obj["message"] as? [String: Any] {
                // Count assistant messages
                if let role = message["role"] as? String, role == "assistant" {
                    assistantMessages += 1
                } else if obj["type"] as? String == "assistant" {
                    assistantMessages += 1
                }

                // Model from message.model
                if session.modelName == nil, let model = message["model"] as? String {
                    session.modelName = displayName(for: model)
                }

                // Token usage + per-model cost from message.usage
                if let usage = message["usage"] as? [String: Any] {
                    let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
                    let cacheWrite = usage["cache_creation_input_tokens"] as? Int ?? 0
                    let input = (usage["input_tokens"] as? Int ?? 0)
                        + cacheRead
                        + cacheWrite
                    let output = usage["output_tokens"] as? Int ?? 0
                    totalInputTokens += input
                    totalOutputTokens += output
                    totalCacheRead += cacheRead
                    totalCacheWrite += cacheWrite

                    // Web search/fetch from server_tool_use
                    if let serverTool = usage["server_tool_use"] as? [String: Any] {
                        webSearches += serverTool["web_search_requests"] as? Int ?? 0
                        webFetches += serverTool["web_fetch_requests"] as? Int ?? 0
                    }

                    if let model = message["model"] as? String {
                        let name = displayName(for: model)
                        let cost = Self.calculateCost(model: name, input: input, output: output, cacheRead: cacheRead, cacheWrite: cacheWrite)
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
        session.cacheReadTokens = totalCacheRead
        session.cacheWriteTokens = totalCacheWrite
        session.webSearchCount = webSearches
        session.webFetchCount = webFetches
        session.messageCount = assistantMessages

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
        let readSize: UInt64 = min(fileSize, 524288)
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
                let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
                let cacheWrite = usage["cache_creation_input_tokens"] as? Int ?? 0
                let input = (usage["input_tokens"] as? Int ?? 0) + cacheRead + cacheWrite
                let output = usage["output_tokens"] as? Int ?? 0
                let name = displayName(for: model)
                totalCost += Self.calculateCost(model: name, input: input, output: output, cacheRead: cacheRead, cacheWrite: cacheWrite)
            }

            if costFromTracker == nil,
               let costTracker = obj["costTracker"] as? [String: Any],
               let cost = costTracker["totalCost"] as? Double {
                costFromTracker = cost
            }
        }

        return costFromTracker ?? totalCost
    }

    /// Parse task info from all .jsonl transcripts in a project directory.
    /// Efficient: reads first 1KB for title, last 32KB for token sums.
    private func parseTasksForProject(transcripts: [(url: URL, date: Date)]) -> [TaskInfo] {
        var tasks: [TaskInfo] = []
        let fm = FileManager.default

        for entry in transcripts {
            let url = entry.url
            let filename = url.deletingPathExtension().lastPathComponent
            guard let handle = try? FileHandle(forReadingFrom: url) else { continue }
            defer { handle.closeFile() }

            let fileSize = handle.seekToEndOfFile()
            guard fileSize > 0 else { continue }

            // --- Read first 1KB for title ---
            handle.seek(toFileOffset: 0)
            let headSize: UInt64 = min(fileSize, 1024)
            let headData = handle.readData(ofLength: Int(headSize))
            let headStr = String(data: headData, encoding: .utf8) ?? ""

            var title = "Untitled"
            // Find first user message
            for line in headStr.split(separator: "\n") {
                guard let lineData = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
                else { continue }
                let type = obj["type"] as? String
                if type == "human" || type == "user" {
                    if let msg = obj["message"] as? [String: Any],
                       let content = msg["content"] as? String {
                        title = String(content.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if let content = obj["content"] as? String {
                        title = String(content.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if let parts = (obj["message"] as? [String: Any])?["content"] as? [[String: Any]],
                              let first = parts.first, let text = first["text"] as? String {
                        title = String(text.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    break
                }
            }

            // --- Read last 32KB for token sums ---
            let tailSize: UInt64 = min(fileSize, 32768)
            handle.seek(toFileOffset: fileSize - tailSize)
            let tailData = handle.readDataToEndOfFile()
            let tailStr = String(data: tailData, encoding: .utf8) ?? ""

            var info = TaskInfo(id: filename, title: title)
            info.lastActivity = entry.date
            var messageCount = 0

            for line in tailStr.split(separator: "\n") {
                guard let lineData = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
                else { continue }

                messageCount += 1

                if let message = obj["message"] as? [String: Any] {
                    if info.modelName == nil, let model = message["model"] as? String {
                        info.modelName = displayName(for: model)
                    }
                    if let usage = message["usage"] as? [String: Any] {
                        let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
                        let cacheWrite = usage["cache_creation_input_tokens"] as? Int ?? 0
                        let input = usage["input_tokens"] as? Int ?? 0
                        let output = usage["output_tokens"] as? Int ?? 0

                        info.inputTokens += input
                        info.outputTokens += output
                        info.cacheReadTokens += cacheRead
                        info.cacheWriteTokens += cacheWrite

                        if let model = message["model"] as? String {
                            let name = displayName(for: model)
                            info.estimatedCost += Self.calculateCost(
                                model: name,
                                input: input + cacheRead + cacheWrite,
                                output: output,
                                cacheRead: cacheRead,
                                cacheWrite: cacheWrite
                            )
                        }
                    }
                }
            }
            info.messageCount = messageCount

            // Use file mod date for last activity
            if let attrs = try? fm.attributesOfItem(atPath: url.path),
               let modDate = attrs[.modificationDate] as? Date {
                info.lastActivity = modDate
            }

            tasks.append(info)
        }

        return tasks.sorted { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }
    }

    private func detectGitBranch(from transcriptURL: URL) -> String? {
        #if os(macOS)
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
        #else
        return nil
        #endif
    }

    /// Cache-aware cost calculation using Anthropic's published pricing.
    /// Cache reads are 90% cheaper, cache writes are 25% more expensive than base input.
    private static func calculateCost(model: String, input: Int, output: Int, cacheRead: Int = 0, cacheWrite: Int = 0) -> Double {
        let (inPrice, cacheReadPrice, cacheWritePrice, outPrice): (Double, Double, Double, Double) = switch model {
        case "Opus": (15.0, 1.50, 18.75, 75.0)
        case "Sonnet": (3.0, 0.30, 3.75, 15.0)
        case "Haiku": (0.25, 0.025, 0.3125, 1.25)
        default: (3.0, 0.30, 3.75, 15.0)
        }
        // input param includes cache tokens when called from old code paths;
        // subtract them out if cache breakdown is provided
        let baseInput = max(0, input - cacheRead - cacheWrite)
        return (Double(baseInput) / 1_000_000) * inPrice
            + (Double(cacheRead) / 1_000_000) * cacheReadPrice
            + (Double(cacheWrite) / 1_000_000) * cacheWritePrice
            + (Double(output) / 1_000_000) * outPrice
    }

    private func displayName(for modelId: String) -> String {
        if modelId.contains("opus") { return "Opus" }
        if modelId.contains("sonnet") { return "Sonnet" }
        if modelId.contains("haiku") { return "Haiku" }
        return modelId
    }
}
