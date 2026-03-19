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
    public func getHistory() -> [DailySnapshot] {
        return loadHistory()
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
