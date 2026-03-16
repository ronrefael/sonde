import Foundation

/// Shared time formatting utilities.
public enum TimeFormatting {
    /// Format an RFC3339 reset timestamp as a countdown string.
    public static func formatResetCountdown(from rfc3339: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let resetDate = formatter.date(from: rfc3339)
                ?? ISO8601DateFormatter().date(from: rfc3339)
        else {
            return rfc3339
        }

        let diff = resetDate.timeIntervalSince(Date())
        if diff <= 0 { return "now" }

        let hours = Int(diff) / 3600
        let mins = (Int(diff) % 3600) / 60

        if hours > 0 {
            return "\(hours)h\(String(format: "%02d", mins))m"
        }
        return "\(mins)m"
    }

    /// Format seconds as a human-readable duration.
    public static func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return "\(hours)h\(String(format: "%02d", mins))m"
        }
        if mins > 0 {
            return "\(mins)m\(String(format: "%02d", secs))s"
        }
        return "\(secs)s"
    }
}
