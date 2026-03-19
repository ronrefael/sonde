import Foundation
import SwiftUI

/// 6-tier pacing assessment matching the Rust binary.
public enum PaceTier: String, Sendable, Equatable {
    case comfortable = "Comfortable"
    case onTrack = "On Track"
    case elevated = "Elevated"
    case hot = "Hot"
    case critical = "Critical"
    case runaway = "Runaway"

    /// Text emoji for menu bar label (SF Symbols don't render in NSStatusItem).
    public var emoji: String {
        switch self {
        case .comfortable: "●"
        case .onTrack: "●"
        case .elevated: "▲"
        case .hot: "▲"
        case .critical: "✕"
        case .runaway: "⊘"
        }
    }

    /// SF Symbol name for use in SwiftUI views.
    public var icon: String {
        switch self {
        case .comfortable: "checkmark.circle.fill"
        case .onTrack: "checkmark.circle"
        case .elevated: "exclamationmark.triangle.fill"
        case .hot: "flame.fill"
        case .critical: "xmark.octagon.fill"
        case .runaway: "nosign"
        }
    }

    public var swiftColor: Color {
        switch self {
        case .comfortable: .green
        case .onTrack: .blue
        case .elevated: .yellow
        case .hot: .orange
        case .critical: .red
        case .runaway: .red
        }
    }

    /// Predict when the user will hit 100% utilization.
    /// Returns nil if pace is comfortable (projected < 100% by reset).
    public static func predictTimeToLimit(utilization: Double, resetsAt: String?) -> String? {
        guard utilization > 10, let resetsAt else { return nil }

        let remaining: TimeInterval
        if let date = TimeFormatting.isoFormatter.date(from: resetsAt)
            ?? TimeFormatting.isoFormatterBasic.date(from: resetsAt)
        {
            remaining = date.timeIntervalSince(Date())
        } else {
            return nil
        }

        guard remaining > 0 else { return nil }

        let windowDuration: TimeInterval = 5 * 3600 // 5-hour window
        let elapsed = windowDuration - remaining
        guard elapsed > 60 else { return nil } // need at least 1 min of data

        let rate = utilization / (elapsed / windowDuration) // projected % at window end
        guard rate > 100 else { return nil } // won't hit limit

        // Time to reach 100% at current rate
        let pctPerSec = utilization / elapsed
        let secsToLimit = (100 - utilization) / pctPerSec
        let minsToLimit = Int(secsToLimit) / 60

        if minsToLimit >= 60 {
            return "Limit in ~\(minsToLimit / 60)h \(minsToLimit % 60)m"
        }
        return "Limit in ~\(minsToLimit)m"
    }

    public static func calculate(utilization: Double, promoActive: Bool) -> PaceTier {
        if utilization > 90.0 {
            return .runaway
        }

        let effective = promoActive ? utilization / 2.0 : utilization

        if effective < 30.0 { return .comfortable }
        if effective < 60.0 { return .onTrack }
        if effective < 80.0 { return .elevated }
        if effective < 100.0 { return .hot }
        return .critical
    }
}
