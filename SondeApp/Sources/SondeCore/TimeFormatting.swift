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
        if diff <= 0 { return "now" }

        let totalSeconds = Int(diff)
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h\(String(format: "%02d", mins))m"
        }
        return "\(mins)m"
    }
}
