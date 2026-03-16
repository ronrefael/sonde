import Foundation

/// Checks the GitHub releases API for a newer version of Sonde.
public actor UpdateChecker {
    public static let shared = UpdateChecker()

    private let currentVersion = "0.1.0"
    private let releasesURL = URL(string: "https://api.github.com/repos/ronrefael/sonde/releases/latest")!

    private var cachedResult: (available: Bool, latestVersion: String)?
    private var cacheDate: Date?
    private let cacheDuration: TimeInterval = 6 * 60 * 60 // 6 hours

    public init() {}

    /// Returns `(available: true, latestVersion)` when a newer release exists, or nil on failure.
    public func check() async -> (available: Bool, latestVersion: String)? {
        // Return cached result if still fresh
        if let cached = cachedResult, let date = cacheDate,
           Date().timeIntervalSince(date) < cacheDuration {
            return cached
        }

        var request = URLRequest(url: releasesURL)
        request.timeoutInterval = 5
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                return nil
            }

            let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            let available = isNewer(latestVersion, than: currentVersion)
            let result = (available: available, latestVersion: latestVersion)

            cachedResult = result
            cacheDate = Date()

            return result
        } catch {
            return nil
        }
    }

    /// Simple semantic-version comparison: returns true when `a` is strictly newer than `b`.
    private func isNewer(_ a: String, than b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        let count = max(aParts.count, bParts.count)
        for i in 0..<count {
            let av = i < aParts.count ? aParts[i] : 0
            let bv = i < bParts.count ? bParts[i] : 0
            if av > bv { return true }
            if av < bv { return false }
        }
        return false
    }
}
