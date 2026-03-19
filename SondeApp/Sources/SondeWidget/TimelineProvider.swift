import WidgetKit
import SwiftUI

// MARK: - WidgetData (duplicated from SondeCore to keep widget extension lean)

/// Minimal copy of WidgetData for decoding App Group UserDefaults.
/// Must stay in sync with SondeCore/SharedDefaults.swift.
private struct WidgetData: Codable {
    let fiveHourUtil: Double?
    let sevenDayUtil: Double?
    let dailyCost: Double
    let paceTier: String
    let fiveHourReset: Date?
    let sevenDayReset: Date?
    let usageHistory: [Double]
    let promoActive: Bool
    let lastUpdated: Date
}

// MARK: - Timeline Entry

struct SondeEntry: TimelineEntry {
    let date: Date
    let fiveHourUtil: Double
    let sevenDayUtil: Double
    let dailyCost: Double
    let paceTier: String
    let fiveHourReset: Date?
    let sevenDayReset: Date?
    let promoActive: Bool
    let isPlaceholder: Bool

    static var placeholder: SondeEntry {
        SondeEntry(
            date: Date(),
            fiveHourUtil: 42.0,
            sevenDayUtil: 35.0,
            dailyCost: 1.23,
            paceTier: "On Track",
            fiveHourReset: Date().addingTimeInterval(3600),
            sevenDayReset: Date().addingTimeInterval(86400),
            promoActive: false,
            isPlaceholder: true
        )
    }
}

// MARK: - Timeline Provider

struct SondeTimelineProvider: TimelineProvider {
    typealias Entry = SondeEntry

    func placeholder(in context: Context) -> SondeEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SondeEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SondeEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func currentEntry() -> SondeEntry {
        guard let defaults = UserDefaults(suiteName: "group.dev.sonde.app"),
              let data = defaults.data(forKey: "widgetData"),
              let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data)
        else {
            return .placeholder
        }

        return SondeEntry(
            date: Date(),
            fiveHourUtil: widgetData.fiveHourUtil ?? 0,
            sevenDayUtil: widgetData.sevenDayUtil ?? 0,
            dailyCost: widgetData.dailyCost,
            paceTier: widgetData.paceTier,
            fiveHourReset: widgetData.fiveHourReset,
            sevenDayReset: widgetData.sevenDayReset,
            promoActive: widgetData.promoActive,
            isPlaceholder: false
        )
    }
}
