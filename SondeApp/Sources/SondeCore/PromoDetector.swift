import Foundation

/// Auto-detects active Claude promotions by polling the official support page.
/// Extracts promo article URLs and combines with PromoSchedule for real-time status.
public actor PromoDetector {
    private static let supportURL = URL(
        string: "https://support.claude.com/en/collections/18031876-usage-and-limits"
    )!

    /// Keywords that indicate a promo article (case-insensitive).
    private static let promoKeywords = [
        "promotion", "promo", "2x", "double", "off-peak", "increased limits",
        "bonus", "usage promotion", "boosted",
    ]

    private var cachedResult: PromoInfo?
    private var lastCheck: Date?
    private let checkInterval: TimeInterval = 3600  // Check once per hour

    public init() {}

    /// Detected promo info.
    public struct PromoInfo: Sendable {
        public let isActive: Bool
        public let title: String
        public let url: String
        public let detectedAt: Date
    }

    /// Check for active promos. Uses cached result if fresh.
    public func detectPromo() async -> PromoInfo? {
        if let cached = cachedResult,
            let lastCheck,
            Date().timeIntervalSince(lastCheck) < checkInterval
        {
            return cached
        }

        lastCheck = Date()

        guard let result = await fetchAndParse() else {
            return cachedResult  // Return stale on failure
        }

        cachedResult = result
        return result
    }

    private func fetchAndParse() async -> PromoInfo? {
        var request = URLRequest(url: Self.supportURL)
        request.timeoutInterval = 10
        // Pretend to be a browser to avoid blocks
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                let html = String(data: data, encoding: .utf8)
            else {
                return nil
            }

            return parseHTML(html)
        } catch {
            return nil
        }
    }

    /// Parse the support page HTML to find promo articles.
    /// Looks for <a> tags with href containing "/articles/" and promo keywords in text.
    private func parseHTML(_ html: String) -> PromoInfo? {
        // Extract all <a href="...">text</a> patterns
        let linkPattern = #"<a[^>]*href="([^"]*\/articles\/[^"]*)"[^>]*>([^<]*)<"#
        guard let regex = try? NSRegularExpression(pattern: linkPattern, options: .caseInsensitive)
        else {
            return nil
        }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))

        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let urlStr = nsHTML.substring(with: match.range(at: 1))
            let title = nsHTML.substring(with: match.range(at: 2))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let titleLower = title.lowercased()

            // Check if this article title matches promo keywords
            let isPromo = Self.promoKeywords.contains { keyword in
                titleLower.contains(keyword)
            }

            if isPromo {
                // Normalize URL
                let fullURL: String
                if urlStr.hasPrefix("http") {
                    fullURL = urlStr
                } else if urlStr.hasPrefix("/") {
                    fullURL = "https://support.claude.com\(urlStr)"
                } else {
                    fullURL = urlStr
                }

                return PromoInfo(
                    isActive: true,
                    title: title,
                    url: fullURL,
                    detectedAt: Date()
                )
            }
        }

        return nil
    }
}
