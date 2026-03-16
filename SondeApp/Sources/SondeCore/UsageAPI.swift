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

/// Fetches usage data independently — works with or without Claude Code running.
/// Priority: 1) Direct API call  2) Rust cache  3) In-memory stale data
public actor UsageService {
    private static let apiURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private var cachedData: UsageData?
    private var lastSuccessfulFetch: Date?
    private let apiCooldown: TimeInterval = 60  // Don't hit API more than once per minute
    private var lastAPIAttempt: Date?
    private var consecutiveFailures = 0

    public init() {}

    /// Returns (data, lastUpdated) — lastUpdated is nil if no data ever fetched.
    public func fetchUsage() async -> (UsageData?, Date?) {
        // Return in-memory cached if still fresh
        if let cached = cachedData,
           let lastFetch = lastSuccessfulFetch,
           Date().timeIntervalSince(lastFetch) < apiCooldown
        {
            return (cached, lastFetch)
        }

        // Backoff on consecutive failures (30s, 60s, 120s, max 300s)
        if let lastAttempt = lastAPIAttempt, consecutiveFailures > 0 {
            let backoff = min(30.0 * pow(2.0, Double(consecutiveFailures - 1)), 300)
            if Date().timeIntervalSince(lastAttempt) < backoff {
                // Still in backoff — try Rust cache or return stale
                if let fromRust = readRustCache() {
                    cachedData = fromRust.data
                    lastSuccessfulFetch = fromRust.timestamp
                    return (fromRust.data, fromRust.timestamp)
                }
                return (cachedData, lastSuccessfulFetch)
            }
        }

        // Try direct API call (works without Claude Code running)
        lastAPIAttempt = Date()
        if let token = CredentialProvider.getOAuthToken() {
            var request = URLRequest(url: Self.apiURL)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
            request.timeoutInterval = 5

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    let usage = try JSONDecoder().decode(UsageData.self, from: data)
                    cachedData = usage
                    lastSuccessfulFetch = Date()
                    consecutiveFailures = 0
                    return (usage, lastSuccessfulFetch)
                } else {
                    consecutiveFailures += 1
                }
            } catch {
                consecutiveFailures += 1
            }
        }

        // Fallback: try Rust cache
        if let fromRust = readRustCache() {
            cachedData = fromRust.data
            lastSuccessfulFetch = fromRust.timestamp
            return (fromRust.data, fromRust.timestamp)
        }

        // Last resort: return whatever we have
        return (cachedData, lastSuccessfulFetch)
    }

    /// Read from Rust binary's cache (bonus, not required).
    private func readRustCache() -> (data: UsageData, timestamp: Date)? {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let cachePath = cacheDir.appendingPathComponent("sonde/usage_limits.json")

        guard let raw = try? Data(contentsOf: cachePath),
              let envelope = try? JSONDecoder().decode(CacheEnvelope.self, from: raw)
        else {
            return nil
        }

        let timestamp = Date(timeIntervalSince1970: TimeInterval(envelope.createdAt))
        return (envelope.data, timestamp)
    }
}
