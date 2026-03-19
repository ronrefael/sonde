import Foundation

/// A single day's usage snapshot for the history chart.
public struct DailySnapshot: Codable, Equatable {
    public let date: String
    public var fiveHourPeak: Double
    public var sevenDayPeak: Double
    public var dailyCost: Double

    enum CodingKeys: String, CodingKey {
        case date
        case fiveHourPeak = "five_hour_peak"
        case sevenDayPeak = "seven_day_peak"
        case dailyCost = "daily_cost"
    }

    public init(date: String, fiveHourPeak: Double, sevenDayPeak: Double, dailyCost: Double) {
        self.date = date
        self.fiveHourPeak = fiveHourPeak
        self.sevenDayPeak = sevenDayPeak
        self.dailyCost = dailyCost
    }
}

/// Tracks daily usage peaks and persists them to ~/Library/Caches/sonde/usage_history.json.
public final class UsageHistoryTracker {
    private let fileURL: URL
    private let maxDays = 14

    public init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = caches.appendingPathComponent("sonde")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("usage_history.json")
    }

    /// Record current values, keeping the max of current vs stored peak for today.
    public func record(fiveHour: Double?, sevenDay: Double?, cost: Double?) {
        var history = loadHistory()
        let today = Self.todayString()

        if let idx = history.firstIndex(where: { $0.date == today }) {
            if let fh = fiveHour {
                history[idx].fiveHourPeak = max(history[idx].fiveHourPeak, fh)
            }
            if let sd = sevenDay {
                history[idx].sevenDayPeak = max(history[idx].sevenDayPeak, sd)
            }
            if let c = cost {
                history[idx].dailyCost = max(history[idx].dailyCost, c)
            }
        } else {
            history.append(DailySnapshot(
                date: today,
                fiveHourPeak: fiveHour ?? 0,
                sevenDayPeak: sevenDay ?? 0,
                dailyCost: cost ?? 0
            ))
        }

        // Prune entries older than maxDays
        if history.count > maxDays {
            history = Array(history.suffix(maxDays))
        }

        saveHistory(history)
    }

    /// Return the stored history (up to 14 days).
    /// On first call, backfills from ~/.claude/ session transcripts if history is sparse.
    public func getHistory() -> [DailySnapshot] {
        var history = loadHistory()
        if history.count < 3 {
            backfillFromSessions(&history)
            saveHistory(history)
        }
        return history
    }

    /// Scan ~/.claude/projects/ for session transcripts and estimate daily activity
    /// from file modification dates. This gives us historical bars even before the app
    /// was tracking usage.
    private func backfillFromSessions(_ history: inout [DailySnapshot]) {
        guard let home = FileManager.default.homeDirectoryForCurrentUser as URL? else { return }
        let projectsDir = home.appendingPathComponent(".claude/projects")
        guard FileManager.default.fileExists(atPath: projectsDir.path) else { return }

        let cal = Calendar.current
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        dateFmt.timeZone = .current

        // Collect modification dates from .jsonl files in the last 14 days
        var activityByDay: [String: Int] = [:]
        let cutoff = cal.date(byAdding: .day, value: -14, to: Date()) ?? Date()

        guard let enumerator = FileManager.default.enumerator(
            at: projectsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension == "jsonl" else { continue }
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modDate = values.contentModificationDate,
                  modDate > cutoff
            else { continue }

            let dayKey = dateFmt.string(from: modDate)
            activityByDay[dayKey, default: 0] += 1
        }

        // Convert session count to estimated utilization (heuristic: more sessions = higher usage)
        // This is approximate — better than empty bars
        let maxSessions = max(activityByDay.values.max() ?? 1, 1)
        for (day, count) in activityByDay {
            if history.contains(where: { $0.date == day }) { continue }
            // Scale: sessions relative to busiest day, cap at ~80% to not overstate
            let estimatedUtil = min(Double(count) / Double(maxSessions) * 80.0, 80.0)
            history.append(DailySnapshot(
                date: day,
                fiveHourPeak: estimatedUtil,
                sevenDayPeak: 0,
                dailyCost: 0
            ))
        }

        // Sort and prune
        history.sort { $0.date < $1.date }
        if history.count > maxDays {
            history = Array(history.suffix(maxDays))
        }
    }

    // MARK: - Private

    private func loadHistory() -> [DailySnapshot] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([DailySnapshot].self, from: data)) ?? []
    }

    private func saveHistory(_ history: [DailySnapshot]) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}
