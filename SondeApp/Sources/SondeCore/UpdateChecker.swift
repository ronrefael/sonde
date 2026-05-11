import Foundation

/// Checks the GitHub releases API for a newer version of Sonde.
public actor UpdateChecker {
    public static let shared = UpdateChecker()

    /// Read the bundle's `CFBundleShortVersionString` (e.g. "1.0.0") at runtime
    /// instead of hard-coding a value. The previous build hard-coded "0.1.0",
    /// so every installed v1.x.x user saw a permanent false "Update available!"
    /// banner that just pointed at the same release they already had.
    static func resolveCurrentVersion() -> String {
        if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           !v.isEmpty {
            return v
        }
        // Final fallback for unit-test bundles and ad-hoc dev runs. We deliberately
        // pick a sentinel that is *higher* than any plausible release so that we
        // never advertise an upgrade we can't verify; a missing version is treated
        // as "already on a development build", not "needs upgrade".
        return "9999.0.0"
    }

    private let currentVersion: String
    private let releasesURL = URL(string: "https://api.github.com/repos/ronrefael/sonde/releases/latest")!

    private var cachedResult: (available: Bool, latestVersion: String)?
    private var cacheDate: Date?
    private let cacheDuration: TimeInterval = 6 * 60 * 60 // 6 hours

    public init() {
        self.currentVersion = Self.resolveCurrentVersion()
    }

    /// Test seam: build a checker with a known version string.
    init(currentVersion: String) {
        self.currentVersion = currentVersion
    }

    /// Public for tests / diagnostics.
    public func reportedCurrentVersion() -> String {
        currentVersion
    }

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
