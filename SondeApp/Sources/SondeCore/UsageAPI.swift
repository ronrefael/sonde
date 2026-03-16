import Foundation

/// Usage data from the Claude Code OAuth API.
public struct UsageData: Codable, Sendable {
    public let fiveHour: UsageWindow?
    public let sevenDay: UsageWindow?
    public let extraUsage: ExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case extraUsage = "extra_usage"
    }
}

public struct UsageWindow: Codable, Sendable {
    public let utilization: Double?
    public let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

public struct ExtraUsage: Codable, Sendable {
    public let isEnabled: Bool?
    public let monthlyLimit: Double?
    public let usedCredits: Double?
    public let utilization: Double?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case monthlyLimit = "monthly_limit"
        case usedCredits = "used_credits"
        case utilization
    }
}

/// Fetches usage data from the Claude Code OAuth API.
public actor UsageService {
    private static let apiURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private var cachedData: UsageData?
    private var lastFetch: Date?
    private let cacheTTL: TimeInterval = 60

    public init() {}

    public func fetchUsage() async -> UsageData? {
        // Return cached if fresh
        if let cached = cachedData,
           let lastFetch,
           Date().timeIntervalSince(lastFetch) < cacheTTL
        {
            return cached
        }

        guard let token = CredentialProvider.getOAuthToken() else {
            return cachedData // stale fallback
        }

        var request = URLRequest(url: Self.apiURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 5

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            let usage = try decoder.decode(UsageData.self, from: data)
            cachedData = usage
            lastFetch = Date()
            return usage
        } catch {
            return cachedData // stale fallback
        }
    }
}
