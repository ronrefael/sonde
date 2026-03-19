import Foundation

/// Syncs widget data to iCloud Key-Value Store for iPhone companion.
/// macOS: writes after SharedDefaults.write()
/// iOS: reads via NSUbiquitousKeyValueStore notifications
public enum CloudSyncManager {
    private static let key = "widgetData"

    /// Write widget data to iCloud KVS (called from macOS app after SharedDefaults.write).
    public static func write(_ data: WidgetData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        NSUbiquitousKeyValueStore.default.set(encoded, forKey: key)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    /// Read widget data from iCloud KVS (called from iOS app).
    public static func read() -> WidgetData? {
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(WidgetData.self, from: data)
    }
}
