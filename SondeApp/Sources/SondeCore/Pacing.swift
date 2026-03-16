import Foundation

/// 6-tier pacing assessment matching the Rust binary.
public enum PaceTier: String, Sendable {
    case comfortable = "Comfortable"
    case onTrack = "On Track"
    case elevated = "Elevated"
    case hot = "Hot"
    case critical = "Critical"
    case runaway = "Runaway"

    public var emoji: String {
        switch self {
        case .comfortable: "🟢"
        case .onTrack: "🔵"
        case .elevated: "🟡"
        case .hot: "🟠"
        case .critical: "🔴"
        case .runaway: "⛔"
        }
    }

    public var color: String {
        switch self {
        case .comfortable: "green"
        case .onTrack: "blue"
        case .elevated: "yellow"
        case .hot: "orange"
        case .critical: "red"
        case .runaway: "red"
        }
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
