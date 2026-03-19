import Foundation

/// Promo status from PromoClock API.
public struct PromoStatus: Codable, Sendable {
    public let emoji: String?
    public let label: String?
    public let isOffpeak: Bool?
    public let peakWindowUTC: String?
    public let promotionStart: String?
    public let promotionEnd: String?
    public let limitsMultiplier: Int?
    /// URL to the announcement page (if provided by the API).
    public let announcementUrl: String?

    enum CodingKeys: String, CodingKey {
        case emoji, label, peakWindowUTC, promotionStart, promotionEnd, limitsMultiplier, announcementUrl
        case isOffpeak = "isOffPeak"
    }

    /// Best URL for the current promo — API-provided or fallback.
    public var promoUrl: String {
        announcementUrl ?? "https://support.claude.com/en/articles/14063676-claude-march-2026-usage-promotion"
    }

    /// Auto-generated description from API fields.
    public var promoDescription: String {
        var parts: [String] = []

        let multiplier = limitsMultiplier ?? 2
        if isOffpeak == true {
            parts.append("You have \(multiplier)x rate limits during off-peak hours.")
        } else {
            parts.append("Rate limits are at normal levels during peak hours.")
        }

        if let window = peakWindowUTC {
            parts.append("Peak: \(window).")
        }

        if let start = formatShortDate(promotionStart), let end = formatShortDate(promotionEnd) {
            parts.append("Promo: \(start) – \(end).")
        }

        return parts.joined(separator: " ")
    }

    private func formatShortDate(_ iso: String?) -> String? {
        guard let iso else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return nil }
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }
}

/// Fetches promo status from PromoClock API.
public actor PromoService {
    private static let apiURL = URL(string: "https://promoclock.co/api/status")!
    private var cachedStatus: PromoStatus?
    private var lastFetch: Date?
    private let cacheTTL: TimeInterval = 300

    public init() {}

    public func fetchPromo() async -> PromoStatus? {
        if let cached = cachedStatus,
           let lastFetch,
           Date().timeIntervalSince(lastFetch) < cacheTTL
        {
            return cached
        }

        var request = URLRequest(url: Self.apiURL)
        request.timeoutInterval = 3

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let status = try JSONDecoder().decode(PromoStatus.self, from: data)
            cachedStatus = status
            lastFetch = Date()
            return status
        } catch {
            return cachedStatus
        }
    }
}
