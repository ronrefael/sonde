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

/// Rust binary cache envelope format.
private struct CacheEnvelope: Codable {
    let data: UsageData
    let createdAt: UInt64
    let expiresAt: UInt64
    let fiveHourResetsAt: UInt64?

    enum CodingKeys: String, CodingKey {
        case data
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case fiveHourResetsAt = "five_hour_resets_at"
    }
}

/// Fetches usage data — first from Rust binary's shared cache, then API.
public actor UsageService {
    private static let apiURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private var cachedData: UsageData?
    private var lastFetch: Date?
    private let cacheTTL: TimeInterval = 60

    public init() {}

    public func fetchUsage() async -> UsageData? {
        // Return in-memory cached if fresh
        if let cached = cachedData,
           let lastFetch,
           Date().timeIntervalSince(lastFetch) < cacheTTL
        {
            return cached
        }

        // Try reading from Rust binary's shared cache first
        if let fromCache = readRustCache() {
            cachedData = fromCache
            lastFetch = Date()
            return fromCache
        }

        // Fall back to direct API call
        guard let token = CredentialProvider.getOAuthToken() else {
            return cachedData
        }

        var request = URLRequest(url: Self.apiURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 5

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            // Check for rate limiting
            if let http = response as? HTTPURLResponse, http.statusCode == 429 {
                return cachedData
            }
            let usage = try JSONDecoder().decode(UsageData.self, from: data)
            cachedData = usage
            lastFetch = Date()
            return usage
        } catch {
            return cachedData
        }
    }

    /// Read from the Rust binary's cache file at ~/Library/Caches/sonde/usage_limits.json
    private func readRustCache() -> UsageData? {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let cachePath = cacheDir.appendingPathComponent("sonde/usage_limits.json")

        guard let data = try? Data(contentsOf: cachePath) else {
            return nil
        }

        guard let envelope = try? JSONDecoder().decode(CacheEnvelope.self, from: data) else {
            return nil
        }

        // Check window reset — data is invalid after reset
        let now = UInt64(Date().timeIntervalSince1970)
        if let resets = envelope.fiveHourResetsAt, now >= resets {
            return nil
        }

        // Allow stale reads — the Rust statusline refreshes this cache
        // frequently, and the menu bar app should show the last known
        // data rather than nothing when the cache TTL has passed.

        return envelope.data
    }
}
