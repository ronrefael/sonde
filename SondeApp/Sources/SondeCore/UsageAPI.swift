import Foundation
import os.log

private let logger = Logger(subsystem: "dev.sonde.app", category: "UsageService")

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
        // Always check Rust cache first — the Rust binary gets fresh data
        // on every Claude Code statusline render and writes it here.
        // This is more reliable than our own API calls which get rate-limited.
        if let fromRust = readRustCache() {
            let rustAge = Date().timeIntervalSince(fromRust.timestamp)
            let inMemoryAge = lastSuccessfulFetch.map { Date().timeIntervalSince($0) } ?? .infinity

            // Use Rust cache if it's fresher than our in-memory data
            if rustAge < inMemoryAge || rustAge < 120 { // Within 2 min = fresh enough
                cachedData = fromRust.data
                lastSuccessfulFetch = fromRust.timestamp
                return (fromRust.data, fromRust.timestamp)
            }
        }

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
                return (cachedData, lastSuccessfulFetch)
            }
        }

        // Try direct API call
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
                    writeToSharedCache(data)
                    logger.info("Usage API fetch succeeded")
                    return (usage, lastSuccessfulFetch)
                } else {
                    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                    logger.warning("Usage API returned HTTP \(status)")
                    if status == 401 {
                        CredentialProvider.invalidateCachedToken()
                    }
                    consecutiveFailures += 1
                }
            } catch {
                logger.warning("Usage API request failed: \(error.localizedDescription)")
                consecutiveFailures += 1
            }
        } else {
            logger.warning("No OAuth token available — skipping API call")
        }

        // Last resort: return whatever we have
        return (cachedData, lastSuccessfulFetch)
    }

    /// Write API response to shared cache so the Rust statusline picks it up.
    private func writeToSharedCache(_ rawData: Data) {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let dir = cacheDir.appendingPathComponent("sonde")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("usage_limits.json")

        // Write in the same envelope format the Rust binary uses
        let now = UInt64(Date().timeIntervalSince1970)
        let envelope: [String: Any] = [
            "data": (try? JSONSerialization.jsonObject(with: rawData)) ?? [:],
            "created_at": now,
            "expires_at": now + 120, // 2 min TTL — Swift refreshes every 60s
            "five_hour_resets_at": NSNull(),
        ]
        if let json = try? JSONSerialization.data(withJSONObject: envelope) {
            try? json.write(to: path, options: .atomic)
        }
    }

    /// Read from Rust binary's cache (bonus, not required).
    /// Uses the real (non-sandboxed) home path since the Rust binary writes outside the sandbox.
    private func readRustCache() -> (data: UsageData, timestamp: Date)? {
        let realHome: String
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            realHome = String(cString: dir)
        } else {
            guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                return nil
            }
            realHome = cacheDir.deletingLastPathComponent().deletingLastPathComponent().path
        }
        let cachePath = URL(fileURLWithPath: realHome)
            .appendingPathComponent("Library/Caches/sonde/usage_limits.json")

        guard let raw = try? Data(contentsOf: cachePath),
              let envelope = try? JSONDecoder().decode(CacheEnvelope.self, from: raw)
        else {
            return nil
        }

        let timestamp = Date(timeIntervalSince1970: TimeInterval(envelope.createdAt))
        return (envelope.data, timestamp)
    }
}
