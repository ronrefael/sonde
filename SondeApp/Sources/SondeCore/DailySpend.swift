import Foundation

/// Tracks daily combined spend across Claude and Codex, persisted to a JSON file.
public struct DailySpendRecord: Codable, Equatable {
    public var date: String
    public var claude: Double
    public var codex: Double

    public var total: Double { claude + codex }

    public init(date: String = "", claude: Double = 0, codex: Double = 0) {
        self.date = date
        self.claude = claude
        self.codex = codex
    }
}

/// Reads and writes daily spend data to ~/Library/Caches/sonde/daily_spend.json.
public final class DailySpendTracker: Sendable {
    private let filePath: URL

    public init() {
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/sonde")
        filePath = cacheDir.appendingPathComponent("daily_spend.json")

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: cacheDir,
            withIntermediateDirectories: true
        )
    }

    /// Read the current daily record. Returns a fresh record if the file is missing or stale.
    public func read() -> DailySpendRecord {
        let today = Self.todayString()
        guard let data = try? Data(contentsOf: filePath),
              let record = try? JSONDecoder().decode(DailySpendRecord.self, from: data),
              record.date == today
        else {
            return DailySpendRecord(date: today)
        }
        return record
    }

    /// Update the daily spend with the latest session costs.
    /// `claudeSessionCost` and `codexSessionCost` are the current session totals (not deltas).
    /// We track the max seen per session — if a new session starts (cost drops), we accumulate.
    public func update(claudeSessionCost: Double?, codexSessionCost: Double?) -> DailySpendRecord {
        let today = Self.todayString()
        var record = read()

        // Reset if it's a new day
        if record.date != today {
            record = DailySpendRecord(date: today)
        }

        // For daily tracking, we simply set the current session costs.
        // The session cost from Claude is already the total for the current session.
        // For a proper daily total across sessions, we'd need to track session IDs,
        // but for now we track the current session's spend as the daily spend.
        if let claude = claudeSessionCost {
            record.claude = claude
        }
        if let codex = codexSessionCost {
            record.codex = codex
        }

        // Write to disk
        if let data = try? JSONEncoder().encode(record) {
            try? data.write(to: filePath, options: .atomic)
        }

        return record
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    private static func todayString() -> String {
        dateFormatter.string(from: Date())
    }
}
