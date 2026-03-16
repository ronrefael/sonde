import Foundation

/// Promo status from PromoClock API.
public struct PromoStatus: Codable, Sendable {
    public let emoji: String?
    public let label: String?
    public let isOffpeak: Bool?

    enum CodingKeys: String, CodingKey {
        case emoji, label
        case isOffpeak = "is_offpeak"
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
