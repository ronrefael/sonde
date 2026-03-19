import Foundation

/// Shared time formatting utilities.
public enum TimeFormatting {
    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let isoFormatterBasic = ISO8601DateFormatter()

    /// Format an RFC3339 reset timestamp as a countdown string.
    public static func formatResetCountdown(from rfc3339: String) -> String {
        guard let resetDate = isoFormatter.date(from: rfc3339)
            ?? isoFormatterBasic.date(from: rfc3339)
        else {
            return rfc3339
        }

        let diff = resetDate.timeIntervalSince(Date())
        if diff <= 0 { return "" }

        let totalSeconds = Int(diff)
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h\(String(format: "%02d", mins))m"
        }
        return "\(mins)m"
    }

    /// Return remaining minutes until reset (for elapsed calculation).
    public static func remainingMinutes(from rfc3339: String) -> Int {
        guard let resetDate = isoFormatter.date(from: rfc3339)
            ?? isoFormatterBasic.date(from: rfc3339)
        else { return 0 }
        let diff = resetDate.timeIntervalSince(Date())
        return max(0, Int(diff / 60))
    }

    /// Format reset time as local clock time (e.g. "2:30 PM").
    public static func formatResetTime(from rfc3339: String) -> String {
        guard let resetDate = isoFormatter.date(from: rfc3339)
            ?? isoFormatterBasic.date(from: rfc3339)
        else { return "" }
        if resetDate.timeIntervalSince(Date()) <= 0 { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: resetDate)
    }
}
