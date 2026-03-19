import Foundation

/// Data structure shared between the main app and widgets via App Group UserDefaults.
/// SECURITY: Only derived metrics — NEVER include OAuth tokens, API keys, or credential data.
public struct WidgetData: Codable, Sendable {
    public let fiveHourUtil: Double?
    public let sevenDayUtil: Double?
    public let dailyCost: Double
    public let paceTier: String
    public let fiveHourReset: Date?
    public let sevenDayReset: Date?
    public let usageHistory: [Double]
    public let promoActive: Bool
    public let lastUpdated: Date

    public init(
        fiveHourUtil: Double?,
        sevenDayUtil: Double?,
        dailyCost: Double,
        paceTier: String,
        fiveHourReset: Date?,
        sevenDayReset: Date?,
        usageHistory: [Double],
        promoActive: Bool,
        lastUpdated: Date = Date()
    ) {
        self.fiveHourUtil = fiveHourUtil
        self.sevenDayUtil = sevenDayUtil
        self.dailyCost = dailyCost
        self.paceTier = paceTier
        self.fiveHourReset = fiveHourReset
        self.sevenDayReset = sevenDayReset
        self.usageHistory = usageHistory
        self.promoActive = promoActive
        self.lastUpdated = lastUpdated
    }
}

/// Writes widget data to App Group UserDefaults as a single atomic JSON blob.
/// One-directional: main app writes, widgets/iPhone read.
public enum SharedDefaults {
    private static let suiteName = "group.dev.sonde.app"
    private static let key = "widgetData"

    /// Write all widget data atomically (single key to prevent race conditions).
    public static func write(_ data: WidgetData) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return
        }
        guard let encoded = try? JSONEncoder().encode(data) else {
            return
        }
        defaults.set(encoded, forKey: key)
    }

    /// Read widget data (used by widgets and iPhone app).
    public static func read() -> WidgetData? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(WidgetData.self, from: data)
    }
}
