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
    /// If the reset is in the past, projects forward in 5h increments.
    public static func formatResetCountdown(from rfc3339: String) -> String {
        guard let resetDate = resolveResetDate(rfc3339) else { return "" }

        let diff = resetDate.timeIntervalSince(Date())
        if diff <= 0 { return "" }

        let totalSeconds = Int(diff)
        let totalHours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60

        if totalHours >= 24 {
            let days = totalHours / 24
            let hours = totalHours % 24
            return "\(days)d \(hours)h\(String(format: "%02d", mins))m"
        }
        if totalHours > 0 {
            return "\(totalHours)h\(String(format: "%02d", mins))m"
        }
        return "\(mins)m"
    }

    /// Return remaining minutes until reset (for elapsed calculation).
    /// If reset is in the past, returns 0.
    public static func remainingMinutes(from rfc3339: String) -> Int {
        guard let resetDate = parseDate(rfc3339) else { return 0 }
        let diff = resetDate.timeIntervalSince(Date())
        return max(0, Int(diff / 60))
    }

    /// Format reset time as local clock time (e.g. "2:30 PM").
    /// If reset is in the past, projects next reset (5h window = adds 5h).
    public static func formatResetTime(from rfc3339: String) -> String {
        guard let resetDate = resolveResetDate(rfc3339) else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: resetDate)
    }

    /// Resolve a reset date — returns nil if the reset is in the past.
    /// We don't project forward because that's a guess, not real API data.
    private static func resolveResetDate(_ rfc3339: String) -> Date? {
        guard let resetDate = parseDate(rfc3339) else { return nil }
        if resetDate <= Date() { return nil }
        return resetDate
    }

    /// Parse an ISO 8601 / RFC 3339 date string.
    private static func parseDate(_ rfc3339: String) -> Date? {
        isoFormatter.date(from: rfc3339) ?? isoFormatterBasic.date(from: rfc3339)
    }
}
