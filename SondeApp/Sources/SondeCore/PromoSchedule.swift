import Foundation

/// Calculates promo countdown based on the March 2026 schedule.
/// Peak hours: Weekdays 8 AM - 2 PM ET
/// Off-peak: Everything else including all day weekends
public struct PromoSchedule {
    private static let easternTimeZone = TimeZone(identifier: "America/New_York")!

    // Promo runs March 13 - March 28, 2026 at 11:59 PM PT (07:59 UTC March 29)
    private static let promotionEnd: Date = {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 3; comps.day = 29
        comps.hour = 7; comps.minute = 59; comps.second = 0
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: comps) ?? Date.distantFuture
    }()

    /// Returns the label, formatted time remaining, and whether it's currently off-peak.
    public static func nextTransition() -> (label: String, timeRemaining: String, isCurrentlyOffpeak: Bool) {
        let now = Date()

        // After promo ends, return inactive state
        if now >= promotionEnd {
            return ("", "", false)
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = easternTimeZone

        let comps = cal.dateComponents([.hour, .minute, .weekday], from: now)
        guard let hour = comps.hour, let minute = comps.minute, let weekday = comps.weekday else {
            return ("--", "--", true)
        }

        // Sunday = 1, Saturday = 7
        let isWeekend = weekday == 1 || weekday == 7
        let currentMinutes = hour * 60 + minute

        let peakStart = 8 * 60   // 8:00 AM ET
        let peakEnd = 14 * 60    // 2:00 PM ET

        let isPeak = !isWeekend && currentMinutes >= peakStart && currentMinutes < peakEnd

        if isPeak {
            // Currently peak — next transition is to off-peak at 2 PM ET today
            let remainingMinutes = peakEnd - currentMinutes
            let formatted = formatMinutes(remainingMinutes)
            return ("Off-peak in", formatted, false)
        }

        // Currently off-peak — find next peak start
        if isWeekend {
            // Find next Monday 8 AM ET
            let daysUntilMonday: Int
            if weekday == 7 { // Saturday
                daysUntilMonday = 2
            } else { // Sunday
                daysUntilMonday = 1
            }
            guard let nextMonday = cal.date(byAdding: .day, value: daysUntilMonday, to: cal.startOfDay(for: now)) else {
                return ("2x ends", "--", true)
            }
            var mondayComps = cal.dateComponents([.year, .month, .day], from: nextMonday)
            mondayComps.hour = 8
            mondayComps.minute = 0
            guard let peakDate = cal.date(from: mondayComps) else {
                return ("2x ends", "--", true)
            }
            let remaining = Int(peakDate.timeIntervalSince(now) / 60)
            let formatted = formatMinutes(max(remaining, 0))
            return ("2x ends", formatted, true)
        }

        // Weekday, off-peak
        if currentMinutes < peakStart {
            // Before 8 AM — peak starts today
            let remainingMinutes = peakStart - currentMinutes
            let formatted = formatMinutes(remainingMinutes)
            return ("2x ends", formatted, true)
        }

        // After 2 PM — peak starts next weekday at 8 AM
        if weekday == 6 {
            // Friday after 2 PM — next peak is Monday 8 AM
            guard let nextMonday = cal.date(byAdding: .day, value: 3, to: cal.startOfDay(for: now)) else {
                return ("2x ends", "--", true)
            }
            var mondayComps = cal.dateComponents([.year, .month, .day], from: nextMonday)
            mondayComps.hour = 8
            mondayComps.minute = 0
            guard let peakDate = cal.date(from: mondayComps) else {
                return ("2x ends", "--", true)
            }
            let remaining = Int(peakDate.timeIntervalSince(now) / 60)
            let formatted = formatMinutes(max(remaining, 0))
            return ("2x ends", formatted, true)
        } else {
            // Mon-Thu after 2 PM — next peak is tomorrow 8 AM
            guard let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) else {
                return ("2x ends", "--", true)
            }
            var tomorrowComps = cal.dateComponents([.year, .month, .day], from: tomorrow)
            tomorrowComps.hour = 8
            tomorrowComps.minute = 0
            guard let peakDate = cal.date(from: tomorrowComps) else {
                return ("2x ends", "--", true)
            }
            let remaining = Int(peakDate.timeIntervalSince(now) / 60)
            let formatted = formatMinutes(max(remaining, 0))
            return ("2x ends", formatted, true)
        }
    }

    private static func formatMinutes(_ total: Int) -> String {
        if total <= 0 { return "<1m" }
        let totalHours = total / 60
        let mins = total % 60
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
}
